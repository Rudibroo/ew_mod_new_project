using JuMP, HiGHS, CSV, DataFrames

# Load data from CSV files
demand = CSV.read("data/demand.csv", DataFrame)
generation_capacity = CSV.read("data/generation_capacity.csv", DataFrame)
costs = CSV.read("data/costs.csv", DataFrame)
availability = CSV.read("data/availability.csv", DataFrame)

# Time steps (240 hours)
T = 240

# Initialize the model
ESM = Model(HiGHS.Optimizer)

# DSM toggle: Set to true if DSM should be used, false if not
enableDSM = false  # Set to true to use DSM, or false to run without DSM

# V2G toggle: Set to true if V2G should be used, false if not
enableV2G = true  # Set to true to use V2G, or false to run without V2G

# Define decision variables for generation
@variable(ESM, generation[1:T, 1:4] >= 0)  # Generation for wind, solar, coal, gas

# Define DSM variables only if DSM is enabled
if enableDSM
    @variable(ESM, DSM_up[1:T] >= 0)   # DSM shifting demand to later hours
    @variable(ESM, DSM_down[1:T] >= 0) # DSM shifting demand to earlier hours
end

# Define V2G variables only if V2G is enabled
if enableV2G
    @variable(ESM, EV_charge[1:T] >= 0)    # EVs charging from the grid
    @variable(ESM, EV_discharge[1:T] >= 0) # EVs discharging to the grid
    @variable(ESM, EV_storage[1:T] >= 0)   # Energy stored in EVs
end

# V2G parameters (example values)
EV_capacity = 500  # Total capacity of EV fleet in MWh
EV_charge_rate = 100  # Max charging rate in MW
EV_discharge_rate = 100  # Max discharging rate in MW
charge_efficiency = 0.9  # Charging efficiency
discharge_efficiency = 0.9  # Discharging efficiency

# Constraints for demand satisfaction
for hour in 1:T
    if enableDSM
        # With DSM: Adjust demand satisfaction with DSM variables
        total_demand = demand[!, :fixed_demand][hour] + demand[!, :flexible_demand][hour] - DSM_up[hour] + DSM_down[hour]
    else
        # Without DSM: Normal demand satisfaction
        total_demand = demand[!, :fixed_demand][hour] + demand[!, :flexible_demand][hour]
    end

    # Adjust demand satisfaction based on V2G if enabled
    if enableV2G
        @constraint(ESM, sum(generation[hour, :]) + EV_discharge[hour] == total_demand + EV_charge[hour])
    else
        @constraint(ESM, sum(generation[hour, :]) == total_demand)
    end
end

# DSM constraints only if DSM is enabled
if enableDSM
    DSM_max = 1  # Allow DSM to shift up to 100% of flexible demand
    L = 6  # Expand the balancing window to 6 hours for greater flexibility
    for hour in 1:T
        @constraint(ESM, DSM_up[hour] <= DSM_max * demand[!, :flexible_demand][hour])
        @constraint(ESM, DSM_down[hour] <= DSM_max * demand[!, :flexible_demand][hour])
    end

    # DSM balance constraint (shift must balance within a 6-hour window)
    for hour in 1:(T-L)
        @constraint(ESM, sum(DSM_up[hour:hour+L]) == sum(DSM_down[hour:hour+L]))
    end
end

# V2G constraints only if V2G is enabled
if enableV2G
    # V2G constraints for charging, discharging, and storage
    for hour in 1:T
        # Capacity constraints for EV storage
        @constraint(ESM, EV_storage[hour] <= EV_capacity)
        # Charging and discharging rate limits
        @constraint(ESM, EV_charge[hour] <= EV_charge_rate)
        @constraint(ESM, EV_discharge[hour] <= EV_discharge_rate)
    end

    # Energy balance for V2G storage
    for hour in 2:T
        @constraint(ESM, EV_storage[hour] == EV_storage[hour-1] + EV_charge[hour-1] * charge_efficiency 
                                                - EV_discharge[hour-1] / discharge_efficiency)
    end
end

# Capacity constraints for each technology
for tech in 1:4  # 1: wind, 2: solar, 3: coal, 4: gas
    @constraint(ESM, generation[:, tech] .<= generation_capacity[!, :capacity_MW][tech])
end

# Add renewable availability for wind and solar
for hour in 1:T
    @constraint(ESM, generation[hour, 1] <= availability[!, :wind_availability][hour] * generation_capacity[!, :capacity_MW][1])
    @constraint(ESM, generation[hour, 2] <= availability[!, :solar_availability][hour] * generation_capacity[!, :capacity_MW][2])
end

# Curtailment for wind
@variable(ESM, curtailment_wind[1:T] >= 0)
for hour in 1:T
    @constraint(ESM, generation[hour, 1] + curtailment_wind[hour] == availability[!, :wind_availability][hour] * generation_capacity[!, :capacity_MW][1])
end

# Ramp rate constraint: Limit how much generation can change between hours
ramp_rate = 0.1  # For example, plants can only change output by 10% of capacity per hour
for hour in 2:T
    for tech in 3:4  # Apply ramp limits to coal (3) and gas (4)
        @constraint(ESM, generation[hour, tech] - generation[hour-1, tech] <= ramp_rate * generation_capacity[!, :capacity_MW][tech])
        @constraint(ESM, generation[hour-1, tech] - generation[hour, tech] <= ramp_rate * generation_capacity[!, :capacity_MW][tech])
    end
end

# Reserve margin constraint: Ensure that a percentage of total capacity is always reserved
reserve_margin = 0.1  # Require 10% of total capacity to be reserved
for hour in 1:T
    @constraint(ESM, sum(generation[hour, :]) <= (1 - reserve_margin) * sum(generation_capacity[!, :capacity_MW]))
end

# Objective function: Minimize cost using time-varying costs
@objective(ESM, Min, sum(generation[t, tech] * time_varying_costs[t, tech] for t in 1:T, tech in 1:4))

# Solve the model
optimize!(ESM)

# Print results
println("Objective value: ", objective_value(ESM))

# Get the objective value
objective_val = objective_value(ESM)

# Scale the objective value by 1e-6 to convert it to millions
scaled_value = objective_val * 1e-6

# Print the scaled objective value in a more readable format
println("Objective value: ", scaled_value, " million")

# Export generation results to CSV (Include DSM and V2G results only if enabled)
results = DataFrame(hour = 1:T, wind = value.(generation[:, 1]), solar = value.(generation[:, 2]), 
                    coal = value.(generation[:, 3]), gas = value.(generation[:, 4]))

# Add V2G results only if V2G is enabled
if enableV2G
    results[!, :EV_charge] = value.(EV_charge)
    results[!, :EV_discharge] = value.(EV_discharge)
end

# Add DSM results only if DSM is enabled
if enableDSM
    results[!, :DSM_up] = value.(DSM_up)
    results[!, :DSM_down] = value.(DSM_down)
end

CSV.write("generation_and_DSM_V2G_results.csv", results)


# Objective values with and without DSM
objective_dsm_enabled = 5.232363541940724e7
objective_dsm_disabled = 5.262354499571536e7

# Calculate percentage cost reduction
cost_reduction_percent = ((objective_dsm_disabled - objective_dsm_enabled) / objective_dsm_disabled) * 100

# Print the percentage cost reduction
println("Cost reduction due to DSM: ", round(cost_reduction_percent, digits=2), "%")