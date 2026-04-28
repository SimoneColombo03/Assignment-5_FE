function adjusted_date = business_date_offset(base_date, varargin)

% BUSINESS_DATE_OFFSET Compute a business-adjusted date from a base date plus calendar offsets.
%
%   adjusted_date = BUSINESS_DATE_OFFSET(base_date)
%   adjusted_date = BUSINESS_DATE_OFFSET(base_date, Name, Value, ...)
%
%   Applies year, month, and day offsets to a reference date, then rolls the
%   result to the nearest valid business day according to the chosen
%   convention. Weekend and holiday detection relies on MATLAB's ISBUSDAY
%   (Financial Toolbox).
%
%   Input: calendar date (MATLAB serial date number or datetime scalar)
%
%   Name-Value Parameters (Optional):
%       'year_offset'   - Integer number of years to add  (default: 0).
%       'month_offset'  - Integer number of months to add (default: 0).
%       'day_offset'    - Integer number of days to add   (default: 0).
%       'convention'    - Business-day roll convention (default: 'following'):
%               'following'           - roll forward to the next business day.
%               'modified_following'  - roll forward, but if that crosses the
%                                       month boundary, roll backward instead.
%
%   Output:
%       adjusted_date: Adjusted business date returned as a serial date number

%% 1. Read inputs
    % We convert the datetime into date num:

    if isdatetime(base_date)
        base_date = datenum(base_date);
    end
    
    % We put at zero the optional parameters which have not been present at
    % input:

    p = inputParser;
    addParameter(p, 'year_offset',  0,           @isnumeric); %We expect a number, default = 0
    addParameter(p, 'month_offset', 0,           @isnumeric); % We expect a number, default = 0
    addParameter(p, 'day_offset',   0,           @isnumeric); % We expect a number, default = 0
    addParameter(p, 'convention',   'following', @ischar); % We expect a string, default = 'following'
    parse(p, varargin{:}); % We combine the optional parameters into p:
    
    year_off   = p.Results.year_offset;
    month_off  = p.Results.month_offset;
    day_off    = p.Results.day_offset;
    convention = lower(p.Results.convention);

    %% 2. Apply year/month/day offset

    % We compute the shifts with the function apply_offset (below):

    raw_date = apply_offset(base_date, year_off, month_off, day_off);

    %% 3. Roll to business day
    
    % We apply the convention (following or modifiend following) 
    % in the function roll_to_busday (below):

    adjusted_date = roll_to_busday(raw_date, convention);

end


function result = apply_offset(serial_date, y_off, m_off, d_off)

% Takes a serial date, adds year/month/day offsets, returns serial date.
% Handles impossible dates (e.g. 31-Feb becomes 28-Feb).

    dt = datetime(serial_date, 'ConvertFrom', 'datenum');
    [y, m, d] = ymd(dt);

    % Shift months, then figure out which year/month we land on
    total_months = m + m_off;
    extra_years  = floor((total_months - 1) / 12); % we add an extrayear if the months offset pass to the next year
    final_month  = mod(total_months - 1, 12) + 1; % mod returns the rest of the division
    final_year   = y + y_off + extra_years; %Total year shift

    % Clamp day if it exceeds the month (e.g. day 31 in a 30-day month)

    max_day   = eomday(final_year, final_month); % We need to check the last day of the final month
    final_day = min(d, max_day); % e.g. : The day will be 29th of february if d = 31

    % Build date and add day offset (datetime handles month/year overflow)
    result = datenum(datetime(final_year, final_month, final_day) + days(d_off));

end


function adj = roll_to_busday(serial_date, convention)

% Rolls a date to the nearest business day.
%   'following'          -> always forward
%   'modified_following' -> forward, unless that changes the month, then backward

    if strcmp(convention, 'modified_following')
        adj = next_busday(serial_date);

        % If we jumped to a different month, go backward instead
        % We use the function same month
        if ~same_month(serial_date, adj)
            adj = prev_busday(serial_date);
        end
    % If the convention is 'following' instead:

    else 
        adj = next_busday(serial_date);
    end

end


function bd = next_busday(serial_date)
% Move forward until we hit a business day.
    bd = serial_date;
    while ~isbusday(bd)
        bd = bd + 1;
    end
end


function bd = prev_busday(serial_date)
% Move backward until we hit a business day.
    bd = serial_date;
    while ~isbusday(bd)
        bd = bd - 1;
    end
end

function tf = same_month(date1, date2) %returns a logic answer true or false
% Check if two serial dates fall in the same month and year.
    dt1 = datetime(date1, 'ConvertFrom', 'datenum');
    dt2 = datetime(date2, 'ConvertFrom', 'datenum');
    tf  = (month(dt1) == month(dt2)) && (year(dt1) == year(dt2));
end