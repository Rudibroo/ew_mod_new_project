import pandas as pd
import matplotlib.pyplot as plt

# Load the CSV file with generation and DSM/V2G results
df = pd.read_csv("generation_and_DSM_V2G_results.csv")

# List of columns for generation technologies and DSM/V2G variables
columns_to_plot = [
    'biomasse', 
    'wasserkraft', 
    'wind_offshore', 
    'wind_onshore', 
    'photovoltaik', 
    'sonstige_erneuerbare', 
    'braunkohle', 
    'steinkohle', 
    'erdgas', 
    'pumpspeicher', 
    'sonstige_konventionelle', 
    'DSM_up',     # Include DSM_up
    'DSM_down',   # Include DSM_down
    'EV_charge',  # Include EV charging
    'EV_discharge' # Include EV discharging
]

# Check if the columns exist in the dataframe
existing_columns = [col for col in columns_to_plot if col in df.columns]

# Calculate the total energy contribution over the time period for each technology
total_energy = df[existing_columns].sum()

# Filter out technologies with zero contribution
non_zero_columns = total_energy[total_energy > 0].index

# 1. Generate and save the Pie Chart (Overall contribution of each technology/DSM/V2G)
plt.figure(figsize=(8, 8))
plt.pie(total_energy[non_zero_columns], labels=non_zero_columns, autopct='%1.1f%%', startangle=140)
plt.title('Overall Contribution of Power Generation, DSM, and V2G')

# Save the pie chart as an image
plt.savefig("pie_chart_contribution.png")
plt.close()  # Close the figure after saving

# 2. Generate and save the Stacked Line Plot (Temporal power dynamics)
plt.figure(figsize=(10, 6))
plt.stackplot(df['hour'], df[non_zero_columns].T, labels=non_zero_columns)

# Add labels and title
plt.xlabel('Hour')
plt.ylabel('Power Output (MW)')
plt.title('Stacked Line Plot of Power Generation, DSM, and V2G')
plt.legend(loc='upper left')
plt.grid(True)

# Save the stacked line plot as an image
plt.savefig("stacked_line_plot_contribution.png")
plt.close()  # Close the figure after saving
