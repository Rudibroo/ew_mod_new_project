import csv
import numpy as np

# Define technologies
technologies = [
    "hour", "Biomasse", "Wasserkraft", "Wind Offshore", "Wind Onshore", 
    "Photovoltaik", "Sonstige Erneuerbare", "Braunkohle", 
    "Steinkohle", "Erdgas", "Pumpspeicher", "Sonstige Konventionelle"
]

# Number of time steps (hours)
T = 336

# Generate realistic time-varying availabilities for each technology
def generate_time_varying_availability(hour):
    # Example: Solar follows a daily pattern (more availability during day, none at night)
    solar_availability = max(0, np.sin(np.pi * (hour % 24) / 24))  # Simple daily sine pattern
    # Example: Wind Offshore follows a smooth curve between 0.5 and 0.9
    wind_offshore_availability = 0.5 + 0.4 * np.sin(2 * np.pi * (hour % 24) / 24)
    # Example: Wind Onshore follows a similar pattern but with lower max availability
    wind_onshore_availability = 0.3 + 0.4 * np.sin(2 * np.pi * (hour % 24) / 24)
    # Example: Biomass and coal are constant, but can have small fluctuations
    biomass_availability = 0.9 + np.random.uniform(-0.02, 0.02)
    braunkohle_availability = 0.95 + np.random.uniform(-0.01, 0.01)
    steinkohle_availability = 0.9 + np.random.uniform(-0.02, 0.02)
    erdgas_availability = 0.85 + np.random.uniform(-0.02, 0.02)
    wasserkraft_availability = 0.7 + np.random.uniform(-0.02, 0.02)
    sonstige_erneuerbare_availability = 0.6 + np.random.uniform(-0.1, 0.1)
    pumpspeicher_availability = 0.7 + np.random.uniform(-0.1, 0.1)
    sonstige_konventionelle_availability = 0.6 + np.random.uniform(-0.1, 0.1)
    
    return [
        hour, biomass_availability, wasserkraft_availability, wind_offshore_availability, wind_onshore_availability,
        solar_availability, sonstige_erneuerbare_availability, braunkohle_availability, 
        steinkohle_availability, erdgas_availability, pumpspeicher_availability, 
        sonstige_konventionelle_availability
    ]

# Prepare availability data for each hour
availability_data = [generate_time_varying_availability(hour) for hour in range(1, T + 1)]

# Write to CSV file
with open("real_availability.csv", mode="w", newline="") as file:
    writer = csv.writer(file)
    # Write header (technology names)
    writer.writerow(technologies)
    # Write availability data
    writer.writerows(availability_data)

print("real_availability.csv file generated successfully!")
