function discount_interp = get_discount_factor_by_zero_rates_linear_interp(reference_date, ...
    interp_date, dates, discounts)

%   This function converts a set of known discount factors into continuously compounded
%   zero rates, linearly interpolates those rates at the requested dates,
%   and converts back to discount factors. Uses linear extrapolation outside
%   the known date range
%
%   Day-count convention: ACT/365.
%
%   INPUTS:
%       reference_date: Valuation / settlement date (serial date number).
%       interp_date: Date(s) at which to interpolate (scalar or vector).
%       dates: Column of known pillar dates (serial date numbers, sorted in ascending order).
%       discounts: Corresponding discount factors for each pillar date.
%
%   OUTPUTS:
%       discount_interp - Interpolated discount factor(s), same size as
%                         interp_date.
    
    
    % We convert into zero rates the discount factors:

    zero_rates = from_discount_factors_to_zero_rates(reference_date, dates, discounts);

    day_count = 3; % daycount ACT/365

    year_frac_dates  = yearfrac(reference_date, dates, day_count);
    year_frac_interp = yearfrac(reference_date, interp_date, day_count);
    
    % We interpolate on the zero rates already computed:

    zero_interp = interp1(year_frac_dates, zero_rates, year_frac_interp, 'linear', 'extrap');

    % Linear extrapolation beyond the pillar range

    zero_interp(year_frac_interp < year_frac_dates(1))  = zero_rates(1);
    zero_interp(year_frac_interp > year_frac_dates(end)) = zero_rates(end);

    % Once interpolation has been done, we compute the interpolated
    % discount factor:

    discount_interp = exp(-zero_interp .* year_frac_interp);

end

