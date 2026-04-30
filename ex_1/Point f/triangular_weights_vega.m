function bucket_weights = triangular_weights_vega(years_to_maturity)
% TRIANGULAR_WEIGHTS_VEGA - Generates ramp weights for volatility bucketing.
% 
% INPUT:
%   years_to_maturity - [Vector] Maturities of the flat volatility points
%
% OUTPUT:
%   bucket_weights    - [n x 2 Matrix] 
%                       Col 1: Weights for the 0-6y bucket (Short-End).
%                       Col 2: Weights for the 6-10y bucket (Long-End).

    % Ensure input is a column vector and get the number of points
    years_to_maturity = years_to_maturity(:);
    num_points = numel(years_to_maturity);
    bucket_weights = zeros(num_points, 2);

    % Bucket 1: 0-6y Exposure
    % The shock is full (1.0) up to 6 years. 
    % Between 6y and 10y, the influence linearly decays to 0.
    bucket_weights(:, 1) = max(0, min(1, (10 - years_to_maturity) / 4));
    bucket_weights(years_to_maturity <= 6, 1) = 1;

    % Bucket 2: 6-10y Exposure 
    % The shock starts at 0 at the 6y point and linearly increases 
    % to 1.0 at the 10y point. 
    % It remains full (1.0) for any maturity beyond 10 years.
    bucket_weights(:, 2) = max(0, min(1, (years_to_maturity - 6) / 4));
    bucket_weights(years_to_maturity >= 10, 2) = 1;

end