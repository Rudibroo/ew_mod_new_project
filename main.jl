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

# Define decision variables for generation
@variable(ESM, generation[1:T, 1:4] >= 0)  # Generation for wind, solar, coal, gas

# Constraints for demand satisfaction (no DSM yet)
for hour in 1:T
    total_demand = demand.fixed_demand[hour] + demand.flexible_demand[hour]
    @constraint(ESM, sum(generation[hour, :]) == total_demand)
end

# Capacity constraints for each technology
for tech in 1:4  # 1: wind, 2: solar, 3: coal, 4: gas
    @constraint(ESM, generation[:, tech] .<= generation_capacity.capacity_MW[tech])
end

# Add renewable availability for wind and solar
for hour in 1:T
    @constraint(ESM, generation[hour, 1] <= availability.wind_availability[hour] * generation_capacity.capacity_MW[1])
    @constraint(ESM, generation[hour, 2] <= availability.solar_availability[hour] * generation_capacity.capacity_MW[2])
end

# Curtailment
@variable(ESM, curtailment_wind[1:T] >= 0)
for hour in 1:T
    @constraint(ESM, generation[hour, 1] + curtailment_wind[hour] == availability.wind_availability[hour] * generation_capacity.capacity_MW[1])
end

# Capacity constraint
for hour in 1:T
    @constraint(ESM, generation[hour, 1] <= availability.wind_availability[hour] * generation_capacity.capacity_MW[1])  # Wind
    @constraint(ESM, generation[hour, 2] <= availability.solar_availability[hour] * generation_capacity.capacity_MW[2])  # Solar
    @constraint(ESM, generation[hour, 3] <= generation_capacity.capacity_MW[3])  # Coal
    @constraint(ESM, generation[hour, 4] <= generation_capacity.capacity_MW[4])  # Gas
end


# Load storage data
storage_capacity = CSV.read("data/storage_capacity.csv", DataFrame)

# Define storage variables
@variable(ESM, energy_in_storage[1:T, 1:2] >= 0)  # Energy stored for battery and pumped hydro
@variable(ESM, charge[1:T, 1:2] >= 0)  # Charging power for battery and pumped hydro
@variable(ESM, discharge[1:T, 1:2] >= 0)  # Discharging power for battery and pumped hydro

# Storage capacity constraints
for t in 1:T
    @constraint(ESM, energy_in_storage[t, 1] <= storage_capacity.capacity_MWh[1])  # Battery capacity
    @constraint(ESM, energy_in_storage[t, 2] <= storage_capacity.capacity_MWh[2])  # Pumped hydro capacity
end

# Charging and discharging power limits
for t in 1:T
    @constraint(ESM, charge[t, 1] <= storage_capacity.charge_rate_MW[1])  # Battery charge rate
    @constraint(ESM, discharge[t, 1] <= storage_capacity.discharge_rate_MW[1])  # Battery discharge rate
    @constraint(ESM, charge[t, 2] <= storage_capacity.charge_rate_MW[2])  # Pumped hydro charge rate
    @constraint(ESM, discharge[t, 2] <= storage_capacity.discharge_rate_MW[2])  # Pumped hydro discharge rate
end

# Energy balance in storage with efficiency losses
for t in 2:T
    @constraint(ESM, 
        energy_in_storage[t, 1] == energy_in_storage[t-1, 1] + storage_capacity.efficiency_charge[1] * charge[t, 1] 
        - discharge[t, 1] / storage_capacity.efficiency_discharge[1])  # Battery storage balance

    @constraint(ESM, 
        energy_in_storage[t, 2] == energy_in_storage[t-1, 2] + storage_capacity.efficiency_charge[2] * charge[t, 2] 
        - discharge[t, 2] / storage_capacity.efficiency_discharge[2])  # Pumped hydro storage balance
end



# Objective function: Minimize cost
cost = costs.cost_per_MWh
@objective(ESM, Min, sum(generation[t, tech] * cost[tech] for t in 1:T, tech in 1:4) +
                     sum(charge[t, 1] + discharge[t, 1] for t in 1:T))  # Example objective with storage operation cost

# Solve the model
optimize!(ESM)

# Print results
println("Objective value: ", objective_value(ESM))

# Export generation results to CSV
results = DataFrame(hour = 1:T, wind = value.(generation[:, 1]), solar = value.(generation[:, 2]), 
                    coal = value.(generation[:, 3]), gas = value.(generation[:, 4]))
CSV.write("generation_results.csv", results)

println("Git test")