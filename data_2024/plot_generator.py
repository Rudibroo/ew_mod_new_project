import pandas as pd
import matplotlib.pyplot as plt

# Load the data from CSV
df = pd.read_csv('generation_and_DSM_V2G_results.csv')

# Stacked Line Plot: Showing the generation of different technologies over time (hours)
plt.figure(figsize=(10, 6))
df.set_index('hour', inplace=True)
df[['biomasse', 'wasserkraft', 'wind_offshore', 'wind_onshore', 'photovoltaik', 
    'sonstige_erneuerbare', 'braunkohle', 'steinkohle', 'erdgas', 
    'pumpspeicher', 'sonstige_konventionelle']].plot.area(stacked=True, alpha=0.7)

plt.title('Energy Generation by Technology Over Time')
plt.xlabel('Hour')
plt.ylabel('Generated Power (MW)')
plt.legend(loc='upper right')
plt.tight_layout()
plt.savefig('stacked_line_plot.png')
plt.show()

# Pie Chart: Total contribution of each technology over the 336-hour period
total_generation = df[['biomasse', 'wasserkraft', 'wind_offshore', 'wind_onshore', 
                       'photovoltaik', 'sonstige_erneuerbare', 'braunkohle', 
                       'steinkohle', 'erdgas', 'pumpspeicher', 'sonstige_konventionelle']].sum()

plt.figure(figsize=(8, 8))
plt.pie(total_generation, labels=total_generation.index, autopct='%1.1f%%', startangle=140, colors=plt.cm.Paired.colors)
plt.title('Total Energy Generation by Technology (336 Hours)')
plt.tight_layout()
plt.savefig('generation_pie_chart.png')
plt.show()
