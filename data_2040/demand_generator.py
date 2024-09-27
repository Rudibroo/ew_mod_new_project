import pandas as pd
import numpy as np

# Load the original demand data
df = pd.read_csv("total_demand.csv")

# Helper function to create demand profiles
def create_profile(df, profile_type="first"):
    total_demand_per_day = df['total_demand'].groupby(df.index // 24).sum()  # Group by day

    profile = df.copy()

    for day in range(len(total_demand_per_day)):
        if profile_type == "first":
            # Extreme peaks during the day, low during the night
            pattern = np.array([0.6, 0.6, 0.6, 0.65, 0.65, 0.7, 0.8, 0.9, 1.0, 1.2, 1.3, 1.4, 
                                1.4, 1.3, 1.2, 1.0, 0.9, 0.8, 0.7, 0.7, 0.7, 0.65, 0.65, 0.6])
        
        elif profile_type == "second":
            # Inverse profile: High at night, lower during the day
            pattern = np.array([1.4, 1.3, 1.2, 1.2, 1.2, 1.1, 1.0, 0.9, 0.8, 0.7, 0.65, 0.6, 
                                0.6, 0.65, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.3, 1.4, 1.4])
        
        elif profile_type == "third":
            # Interesting pattern: Moderate peaks in morning and evening
            pattern = np.array([0.8, 0.85, 0.9, 0.95, 1.0, 1.05, 1.2, 1.3, 1.3, 1.2, 1.1, 1.0,
                                0.9, 0.85, 0.8, 0.7, 0.65, 0.6, 0.6, 0.65, 0.7, 0.8, 0.85, 0.9])
        
        else:
            raise ValueError("Unknown profile type")
        
        # Normalize the pattern so it sums to 1 for each day
        pattern = pattern / pattern.sum()
        
        # Assign the demand values for the given day
        day_start = day * 24
        day_end = day_start + 24
        profile.loc[day_start:day_end-1, 'total_demand'] = total_demand_per_day[day] * pattern

    return profile

# Create the three profiles
profile_1 = create_profile(df, "first")
profile_2 = create_profile(df, "second")
profile_3 = create_profile(df, "third")

# Save the new profiles to CSV files
profile_1.to_csv("demand_profile_high_peaks.csv", index=False)
profile_2.to_csv("demand_profile_inverse_peaks.csv", index=False)
profile_3.to_csv("demand_profile_balanced_peaks.csv", index=False)

print("Profiles created and saved.")
