function zero_rates = from_discount_factors_to_zero_rates(reference_date, dates, discounts)
% FROM_DISCOUNT_FACTORS_TO_ZERO_RATES Converts discount factors into zero rates.
%
% INPUTS:
%   reference_date : Valuation or curve anchor date (serial date number).
%   dates          : Vector of maturity dates (serial date numbers).
%   discounts      : Vector of discount factors corresponding to the dates.
% 
% OUTPUT:
%   zero_rates     : Vector of continuously compounded zero rates (ACT/365).

    % Define day-count convention: ACT/365
    day_count = 3; 

    % Compute year fractions from the reference date to each maturity date
    year_frac = yearfrac(reference_date, dates, day_count);

    % Initialize the zero rates vector with the same dimensions as discounts
    zero_rates = zeros(size(discounts));

    % Identify strictly positive maturities to avoid division by zero (T = 0)
    idx_positive = (year_frac > 0);

    % Calculate continuously compounded rates: r = -log(B(0,T)) / T
    % This handles all nodes where the maturity is in the future.
    zero_rates(idx_positive) = -log(discounts(idx_positive)) ./ year_frac(idx_positive);

    % Handle the case where T = 0 (year_frac == 0):
    % To ensure interpolation stability, we assign the rate of the first available
    % future node (flat-forward assumption from T=0 to the first pillar).
    if any(~idx_positive)
        first_valid_idx = find(idx_positive, 1, 'first');
        if ~isempty(first_valid_idx)
            % Assign the value of the first calculated zero rate to the T=0 points
            zero_rates(~idx_positive) = zero_rates(first_valid_idx);
        else
            % If no future nodes exist, default the rate to zero
            zero_rates(~idx_positive) = 0;
        end
    end
end