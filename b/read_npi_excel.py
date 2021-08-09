# preliminaries
import os, sys
import pandas as pd
import glob


def read_reshape_state_excel_file(file_name):
    
    # read the excel file into dataframe df
    sheet = 'category' 
    df = pd.read_excel(io=file_name, sheet_name=sheet)

    # count the number of non-null end dates in each row
    df['num_end_dates'] = pd.notnull(df['end_date_1']).astype(int) + pd.notnull(df['end_date_2']).astype(int) + pd.notnull(df['end_date_3']).astype(int)

    # read the full list of districts into a dataset
    full_district_list = pd.read_excel(io=file_name, sheet_name='district')['lgd_district_name'].tolist()

    # GOAL: create an output district-category level dataframe
    output_list = []

    # loop over each row in the data frame
    excel_row = 1
    for i in range(0, len(df.index)):

        # Increment Excel row counter. Note we intentionally start at 2 b/c there is a header row.
        excel_row = excel_row + 1

        # get the row contents
        row = df.loc[i, :]

        # get the district and category
        dist = row['district'].lower().strip()
        category = row['category'].lower().strip()
        start_date = row['start_date']
        num_ends = row['num_end_dates']

        # if it's "all districts", use the full district list
        if dist == 'all districts': dists = full_district_list

        # else, split the district list on commas
        else:
            dists = dist.split(',')

        # loop over the district list
        for district in dists:

            # clean the district name
            district = district.lower().strip()

            # throw a warning and skip if the district isn't in the district list
            if district not in full_district_list:
                print(f'WARNING: skipping district {district} not found in state district list.')
                continue

            # create an entry in the output list for the start date
            output_list.append([excel_row, district, category, start_date, 1])

            # create an entry for each lockdown date
            for e in range(0, num_ends):

                # create the variable name for this end date
                end_date_str = f'end_date_{e+1}'

                # create a series of entries for this lockdown item
                # district, category, date, event
                # where [event] is: +1: closure. -1: reopening. -0.5: reopening in 2 parts, etc..
                # add the entry for this NPI to the output list. Note division of end date into negative fractions for multiple end dates.
                output_list.append([excel_row, district, category, row[end_date_str], -1/num_ends])

                df_out = pd.DataFrame(output_list,columns=['excel_row','district','category','date','npi'])

                # add the state name
                df_out['state'] = os.path.splitext(os.path.basename(file_name))[0]

    # return the dataframe
    return df_out


# In[12]:


# set basepath
datapath = os.path.expanduser('./data')

# set target excel sheet name
sheet = 'category'

print('Processing state files...')

# create an output dataframe
df_all_states = pd.DataFrame()

df_running = pd.DataFrame()

# loop over excel file
for fn in glob.glob(os.path.join(datapath, '*.xls*')):

    print(f'loading {fn}')
    
    # read and reshape the excel file
    df_running = df_running.append(read_reshape_state_excel_file(fn))

# show the data
print(df_running.head())

# write a stata file
df_running.to_stata(os.path.join(datapath, "npi.dta"))
                

