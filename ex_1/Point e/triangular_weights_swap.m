function W = triangular_weights_swap(yf)
% TRIANGULAR_WEIGHTS_SWAP - Generates triangular/ramp weights for Delta bucketing.
%
% INPUT:
%   yf - [Vector] Year fractions of the bootstrap instruments.
%
% OUTPUT:
%   W  - [n x 3 Matrix] Weights for the three buckets:
%        Col 1: 0-2y (Ramp down to 6y)
%        Col 2: 2-6y (Triangle peaking at 6y)
%        Col 3: 6-10y (Ramp up from 6y)

    yf = yf(:);
    n  = numel(yf);
    W  = zeros(n, 3);

    % Bucket 1: 0-2y Exposure
    % Full weight up to 2y, then linearly decays to 0 at 6y
    W(:, 1)        = max(0, min(1, (6 - yf) / 4));
    W(yf <= 2, 1)  = 1;

    % Bucket 2: 2-6y Exposure
    % Triangular profile: peaks at 6y, starts at 2y, ends at 10y
    W(:, 2) = max(0, min((yf - 2)/4, (10 - yf)/4));

    % Bucket 3: 6-10y Exposure
    % Starts at 6y, reaches full weight at 10y, remains 1 beyond
    W(:, 3)        = max(0, min(1, (yf - 6) / 4));
    W(yf >= 10, 3) = 1;
end