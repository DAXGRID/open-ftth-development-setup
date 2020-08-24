#!/bin/bash

cmd  "psql -h 116.203.155.79 -p 32192 -U postgres -d OPEN_FTTH -a -f ./scripts/dev/truncate_tables.sql"