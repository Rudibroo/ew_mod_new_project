import pandas as pd
import numpy as np

# Define demand profile for 10 days (240 hours)
T = 360
hours = list(range(1, T + 1))

# Create realistic daily demand pattern
def daily_demand(hour):
    if hour % 24 < 6:       # 12 AM - 6 AM: Low demand (night)
        return np.random.uniform(5000, 6000)
    elif hour % 24 < 12:     # 6 AM - 12 PM: Morning rise
        return np.random.uniform(7000, 10000)
    elif hour % 24 < 18:     # 12 PM - 6 PM: Peak demand
        return np.random.uniform(12000, 15000)
    else:                    # 6 PM - 12 AM: Evening peak and night drop
        return np.random.uniform(8000, 11000)

# Generate demand for each hour
fixed_demand = [daily_demand(h) for h in hours]
flexible_demand = [np.random.uniform(2000, 3000) for h in hours]  # Random flexible demand

# Create DataFrame
demand_data = {
    'hour': hours,
    'fixed_demand': fixed_demand,
    'flexible_demand': flexible_demand
}

# Create the DataFrame and save as "demand.csv"
demand_df = pd.DataFrame(demand_data)
demand_df.to_csv('demand.csv', index=False)



# Create the generation_capacity.csv file
generation_capacity_data = {
    'technology': ['wind', 'solar', 'coal', 'gas'],
    'capacity_MW': [10000, 8000, 5000, 4000]  # Example capacities
}
generation_capacity_df = pd.DataFrame(generation_capacity_data)
generation_capacity_df.to_csv('generation_capacity.csv', index=False)

# Create the costs.csv file
costs_data = {
    'technology': ['wind', 'solar', 'coal', 'gas'],
    'cost_per_MWh': [10, 15, 50, 40]  # Example costs per MWh
}
costs_df = pd.DataFrame(costs_data)
costs_df.to_csv('costs.csv', index=False)

# Create the availability.csv file
availability_data = {
    'hour': list(range(1, 361)),
    'wind_availability': [0.6 + (0.2 * ((i % 5) / 5)) for i in range(360)],  # Example wind availability
    'solar_availability': [0.0 if i % 24 < 6 or i % 24 > 18 else 0.8 for i in range(360)]  # Solar availability (day/night cycle)
}
availability_df = pd.DataFrame(availability_data)
availability_df.to_csv('availability.csv', index=False)


# Create the storage_capacity.csv file
storage_capacity_data = {
    'storage_type': ['battery', 'pumped_hydro'],
    'capacity_MWh': [5000, 20000],  # Maximum energy that can be stored
    'charge_rate_MW': [1000, 2000],  # Maximum rate of charging
    'discharge_rate_MW': [1000, 2000],  # Maximum rate of discharging
    'efficiency_charge': [0.9, 0.85],  # Charging efficiency
    'efficiency_discharge': [0.9, 0.9]  # Discharging efficiency
}

# Create the DataFrame and save it as "storage_capacity.csv"
storage_capacity_df = pd.DataFrame(storage_capacity_data)
storage_capacity_df.to_csv('storage_capacity.csv', index=False)
