# -*- coding: utf-8 -*-
"""
Created on Mon Oct 28 08:18:28 2019

@author: mongi
"""

import dash
import dash_html_components as html
import dash_core_components as dcc
import pandas as pd
import numpy as np
from sodapy import Socrata
import os
import plotly.express as px
import matplotlib.pyplot as plt
import plotly.graph_objects as go

external_stylesheets = ['https://codepen.io/chriddyp/pen/bWLwgP.css']

socrata_domain = 'data.cityofnewyork.us'
socrata_dataset_identifier = 'nwxe-4ae8'

socrata_token = os.environ.get("SODAPY_APPTOKEN")

client = Socrata(socrata_domain, socrata_token)

results = client.get(socrata_dataset_identifier,
                     select="distinct(spc_common)")

list_of_spc_common = [d['spc_common_1'] for d in results if 'spc_common_1' in d]

#list_of_spc_common
#len(list_of_spc_common)

list_of_dict_spc_common = []
for mem in list_of_spc_common:
    #print(mem)
    dict1 = {'label': mem, 'value': mem}
    list_of_dict_spc_common.append(dict1)
    
    
results = client.get(socrata_dataset_identifier,
                     select="distinct(boroname)")

list_of_boroughs = [d['boroname_1'] for d in results if 'boroname_1' in d]

#list_of_boroughs
#list_of_spc_common
#len(list_of_spc_common)

list_of_dict_boroughs = []
for mem in list_of_boroughs:
    #print(mem)
    dict1 = {'label': mem, 'value': mem}
    list_of_dict_boroughs.append(dict1)
    

app = dash.Dash(__name__, external_stylesheets=external_stylesheets)
app.layout = html.Div([
        html.Div([
                dcc.Dropdown(
                        id='my-dropdown1',
                        value='silver maple',
                        options=list_of_dict_spc_common
                        )
                ]),
        html.Div([
                dcc.Dropdown(
                        id='my-dropdown2',
                        value='Brooklyn',
                        options=list_of_dict_boroughs
                        )
                ]),
        html.Div([
                dcc.Graph(id='health_proportion_graph')
                ])
    
    #html.Div(id='output-container')
])


@app.callback(
    dash.dependencies.Output('health_proportion_graph', 'figure'),
    [dash.dependencies.Input('my-dropdown1', 'value'),
     dash.dependencies.Input('my-dropdown2', 'value')])
def update_graph(spc_common_input, borough_input):
    where_clause = "boroname='%s' AND spc_common='%s'" %(borough_input, spc_common_input)
    all_trees_df = pd.DataFrame()
    #loop_size = 1000
    offset_value = 0
    end_of_data = False
    
    while not end_of_data:
        results = client.get(socrata_dataset_identifier,
                         where=where_clause,
                         limit=1000,
                         offset=offset_value)
        offset_value = offset_value + 1000
        if pd.DataFrame(results).empty:
            end_of_data = True
        else:
            all_trees_df = all_trees_df.append(pd.DataFrame(results))
    
    all_trees_df = all_trees_df.reset_index(drop=True)
    
    s = all_trees_df['health'].value_counts()
    
    health_df = pd.DataFrame({'Health_value': s.index, 'Count': s.values})
    
    
    #return { all_trees_df.shape }
    #return 'Shape of the array for the selected values: %s ' % (str(all_trees_df.shape))
    #return 'You have selected spc_common "%s" and borough "%s"' % (spc_common_input, borough_input)
    
    return {
            'data': [
                        go.Pie(labels=health_df['Health_value'], values=health_df['Count'])
                    ]
            }

if __name__ == '__main__':
    app.run_server(debug=True)