using JuMP, HiGHS, CSV, DataFrames, Printf

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
enableDSM = true  # Set to true to use DSM, or false to run without DSM

# Define decision variables for generation
@variable(ESM, generation[1:T, 1:4] >= 0)  # Generation for wind, solar, coal, gas

# Define DSM variables only if DSM is enabled
if enableDSM
    @variable(ESM, DSM_up[1:T] >= 0)   # DSM shifting demand to later hours
    @variable(ESM, DSM_down[1:T] >= 0) # DSM shifting demand to earlier hours
end

# Create a time-varying cost array for each technology (4 technologies)
time_varying_costs = Array{Float64}(undef, T, 4)

# Adjust costs to reflect peak and off-peak pricing
for hour in 1:T
    if mod(hour, 24) >= 12 && mod(hour, 24) <= 18  # Peak hours (12 PM - 6 PM)
        time_varying_costs[hour, 3] = 80  # Coal: 80 €/MWh during peak
        time_varying_costs[hour, 4] = 100  # Gas: 100 €/MWh during peak
    else  # Off-peak hours
        time_varying_costs[hour, 3] = 50  # Coal: 50 €/MWh off-peak
        time_varying_costs[hour, 4] = 40  # Gas: 40 €/MWh off-peak
    end
    # Use static costs for wind and solar
    time_varying_costs[hour, 1] = costs[!, :cost_per_MWh][1]  # Wind
    time_varying_costs[hour, 2] = costs[!, :cost_per_MWh][2]  # Solar
end

# Constraints for demand satisfaction
for hour in 1:T
    if enableDSM
        # With DSM: Adjust demand satisfaction with DSM variables
        total_demand = demand[!, :fixed_demand][hour] + demand[!, :flexible_demand][hour] - DSM_up[hour] + DSM_down[hour]
    else
        # Without DSM: Normal demand satisfaction
        total_demand = demand[!, :fixed_demand][hour] + demand[!, :flexible_demand][hour]
    end
    @constraint(ESM, sum(generation[hour, :]) == total_demand)
end

# DSM constraints only if DSM is enabled
if enableDSM
    DSM_max = 1  # Allow DSM to shift up to 20% of flexible demand
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

# Export generation results to CSV (Include DSM results only if enabled)
if enableDSM
    results = DataFrame(hour = 1:T, wind = value.(generation[:, 1]), solar = value.(generation[:, 2]), 
                        coal = value.(generation[:, 3]), gas = value.(generation[:, 4]),
                        DSM_up = value.(DSM_up), DSM_down = value.(DSM_down))
else
    results = DataFrame(hour = 1:T, wind = value.(generation[:, 1]), solar = value.(generation[:, 2]), 
                        coal = value.(generation[:, 3]), gas = value.(generation[:, 4]))
end

CSV.write("generation_and_DSM_results.csv", results)