function BPV = BasisPointValueFloating(reference_date, maturity_date, dates, discounts)
% Compute the Basis Point Value (BPV) of the floating leg of a swap.
% Vectorized version.
%
% INPUTS:
% reference_date : Valuation date (datetime or datenum)
% maturity_date  : Maturity date (datetime or datenum)
% dates          : Curve dates used for discounting (datenum)
% discounts      : Discount factors corresponding to 'dates'
%
% OUTPUT:
% BPV            : Basis Point Value of the floating leg

% Convert inputs to datetime objects for calendar arithmetic
if ~isdatetime(maturity_date)
    maturity_date = datetime(maturity_date, 'ConvertFrom', 'datenum');
end
if ~isdatetime(reference_date)
    reference_date = datetime(reference_date, 'ConvertFrom', 'datenum');
end

% We calculate the maximum number of 3-month periods (quarterly) between dates
max_periods = ceil(years(maturity_date - reference_date) * 4); 

% We generate all unadjusted potential payment dates going backwards from maturity
potential_payment_dates = maturity_date - calmonths(0:3:(3 * max_periods));

% We filter dates to keep only those strictly after the reference date and sort them
unadj_dates = sort(potential_payment_dates(potential_payment_dates > reference_date));
num_dates = length(unadj_dates);

% We converts datetime to datenum for the business_date_offset function and
% we apply business day adjustment
adj_dates = zeros(num_dates, 1);
for i = 1:num_dates
    adj_dates(i) = business_date_offset(unadj_dates(i), 'convention', 'modified_following');
end

% We compute discount factors for all adjusted dates 
discount_floating = get_discount_factor_by_zero_rates_linear_interp(...
    datenum(reference_date), adj_dates, dates, discounts);

% We compute ACT/360 year fractions
% The start dates for each period are: reference_date (for the 1st) and 
% the previous adjusted payment dates for the subsequent ones
start_dates = [datenum(reference_date); adj_dates(1:end-1)];
end_dates = adj_dates;
yf = yearfrac(start_dates, end_dates, 2); 

% We compute the BPV as the sum of (year fraction * discount factor)
BPV = sum(yf .* discount_floating);

end