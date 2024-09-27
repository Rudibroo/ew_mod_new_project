using JuMP, HiGHS, CSV, DataFrames

#=
# Load data from CSV files, Year 2024
demand = CSV.read("data_2024/total_demand.csv", DataFrame)  # Now this only has total_demand
generation_capacity = CSV.read("data_2024/generation_capacity.csv", DataFrame)
costs = CSV.read("data_2024/costs.csv", DataFrame)
availability = CSV.read("data_2024/availability.csv", DataFrame)
=#
# Load data from CSV files, Year 2040
demand = CSV.read("data_2040/adjusted_total_demand_simulated_large_scale.csv", DataFrame)  # Now this only has total_demand
generation_capacity = CSV.read("data_2040/generation_capacity.csv", DataFrame)
costs = CSV.read("data_2040/costs.csv", DataFrame)
availability = CSV.read("data_2040/availability.csv", DataFrame)

# Time steps (336 hours)
T = 336

# Demand scaling factor (Set to 1.0 for 100% of the demand, 0.5 for 50%, etc.)
demand_scaling_factor = 1.1  # Adjust this value as needed

# Define the fixed and flexible demand ratio (must sum to 1)
fixed_demand_ratio = 1/3  # You can adjust this value for sensitivity analysis
flexible_demand_ratio = 1 - fixed_demand_ratio  # Ensures the sum is 1

# Initialize the model
ESM = Model(HiGHS.Optimizer)

# DSM toggle: Set to true if DSM should be used, false if not
enableDSM = false  # Set to true to use DSM, or false to run without DSM

# V2G toggle: Set to true if V2G should be used, false if not
enableV2G = true  # Set to true to use V2G, or false to run without V2G

# Define decision variables for generation across 11 technologies
@variable(ESM, generation[1:T, 1:11] >= 0)  # Generation for all technologies

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
EV_capacity = 5000  # Total capacity of EV fleet in MWh
EV_charge_rate = 1000  # Max charging rate in MW
EV_discharge_rate = 1000  # Max discharging rate in MW
charge_efficiency = 0.9  # Charging efficiency
discharge_efficiency = 0.9  # Discharging efficiency

# Constraints for demand satisfaction
for hour in 1:T
    # Calculate the fixed and flexible demand from total_demand based on the ratio
    fixed_demand = demand[!, :total_demand][hour] * fixed_demand_ratio
    flexible_demand = demand[!, :total_demand][hour] * flexible_demand_ratio

    if enableDSM
        # With DSM: Adjust demand satisfaction with DSM variables
        total_demand = demand_scaling_factor * (fixed_demand + flexible_demand) - DSM_up[hour] + DSM_down[hour]
    else
        # Without DSM: Normal demand satisfaction
        total_demand = demand_scaling_factor * (fixed_demand + flexible_demand)
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
    L = 20  # Expand the balancing window to 20 hours for greater flexibility
    for hour in 1:T
        # Calculate flexible demand within the loop
        fixed_demand = demand[!, :total_demand][hour] * fixed_demand_ratio
        flexible_demand = demand[!, :total_demand][hour] * flexible_demand_ratio

        # Use flexible demand in the DSM constraints
        @constraint(ESM, DSM_up[hour] <= DSM_max * flexible_demand)
        @constraint(ESM, DSM_down[hour] <= DSM_max * flexible_demand)
    end

    # DSM balance constraint (shift must balance within a 20-hour window)
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
for tech in 1:11  # Update to handle all 11 technologies
    @constraint(ESM, generation[:, tech] .<= generation_capacity[!, :capacity_mw][tech])
end

# Add renewable availability for specific technologies
for hour in 1:T
    # Wind Offshore and Onshore, Photovoltaik (solar), and other renewables
    @constraint(ESM, generation[hour, 3] <= availability[!, :wind_offshore][hour] * generation_capacity[!, :capacity_mw][3])
    @constraint(ESM, generation[hour, 4] <= availability[!, :wind_onshore][hour] * generation_capacity[!, :capacity_mw][4])
    @constraint(ESM, generation[hour, 5] <= availability[!, :photovoltaik][hour] * generation_capacity[!, :capacity_mw][5])
    @constraint(ESM, generation[hour, 6] <= availability[!, :sonstige_erneuerbare][hour] * generation_capacity[!, :capacity_mw][6])
end

# Curtailment for wind
@variable(ESM, curtailment_wind_onshore[1:T] >= 0)
@variable(ESM, curtailment_wind_offshore[1:T] >= 0)
for hour in 1:T
    @constraint(ESM, generation[hour, 3] + curtailment_wind_offshore[hour] == availability[!, :wind_offshore][hour] * generation_capacity[!, :capacity_mw][3])
    @constraint(ESM, generation[hour, 4] + curtailment_wind_onshore[hour] == availability[!, :wind_onshore][hour] * generation_capacity[!, :capacity_mw][4])
end

# Ramp rate constraint: Limit how much generation can change between hours
ramp_rate = 1  # For example, plants can only change output by 10% of capacity per hour
for hour in 2:T
    for tech in 7:9  # Apply ramp limits to Braunkohle (7), Steinkohle (8), and Erdgas (9)
        @constraint(ESM, generation[hour, tech] - generation[hour-1, tech] <= ramp_rate * generation_capacity[!, :capacity_mw][tech])
        @constraint(ESM, generation[hour-1, tech] - generation[hour, tech] <= ramp_rate * generation_capacity[!, :capacity_mw][tech])
    end
end

# Reserve margin constraint: Ensure that a percentage of total capacity is always reserved
reserve_margin = 0.0  # Require 10% of total capacity to be reserved
for hour in 1:T
    @constraint(ESM, sum(generation[hour, :]) <= (1 - reserve_margin) * sum(generation_capacity[!, :capacity_mw]))
end

println("Total demand:", sum(demand[!, :total_demand]) * demand_scaling_factor)
println("Generation capacity:", 336*sum(generation_capacity[!, :capacity_mw]))

# Objective function: Minimize cost using time-varying costs
@objective(ESM, Min, sum(generation[t, tech] * costs[tech, :cost_per_mwh] for t in 1:T, tech in 1:11))

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
results = DataFrame(
    hour = 1:T, 
    biomasse = value.(generation[:, 1]), 
    wasserkraft = value.(generation[:, 2]),
    wind_offshore = value.(generation[:, 3]), 
    wind_onshore = value.(generation[:, 4]), 
    photovoltaik = value.(generation[:, 5]), 
    sonstige_erneuerbare = value.(generation[:, 6]), 
    braunkohle = value.(generation[:, 7]), 
    steinkohle = value.(generation[:, 8]), 
    erdgas = value.(generation[:, 9]), 
    pumpspeicher = value.(generation[:, 10]), 
    sonstige_konventionelle = value.(generation[:, 11])
)

# Add V2G results only if V2G is enabled
if enableV2G
    results[!, :EV_charge] = value.(EV_charge)
    results[!, :EV_discharge] = value.(EV_discharge)
    results[!, :EV_storage] = value.(EV_storage)
end

# Add DSM results only if DSM is enabled
if enableDSM
    results[!, :DSM_up] = value.(DSM_up)
    results[!, :DSM_down] = value.(DSM_down)
end

CSV.write("generation_and_DSM_V2G_results.csv", results)

# Example for calculating and printing the cost reduction due to DSM (if DSM enabled/disabled)
objective_dsm_enabled = 3.6937716306335413e8  # Replace with the actual objective value from your run with DSM enabled
objective_dsm_disabled = 3.7107632507933134e8  # Replace with the actual objective value from your run with DSM disabled

# Calculate percentage cost reduction
cost_reduction_percent = ((objective_dsm_disabled - objective_dsm_enabled) / objective_dsm_disabled) * 100

# Print the percentage cost reduction
println("Cost reduction due to DSM: ", round(cost_reduction_percent, digits=2), "%")
