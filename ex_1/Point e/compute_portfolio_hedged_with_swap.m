function notional_swaps = compute_portfolio_hedged_with_swap(coarse, delta_NPV)
% COMPUTE_PORTFOLIO_HEDGED_WITH_SWAP - Calculates the nominal amounts for hedging swaps.
%
%
% INPUTS:
%   coarse    - [Struct] Result from the coarse DV01 analysis containing:
%               .DV01: [3x1 Vector] Sensitivities of the structured bond (EUR)
%   delta_NPV - [3x3 Matrix] Sensitivity matrix of the hedging swaps, where 
%               each element represents the price change of a swap per 1bp 
%               move in a specific bucket
%
% OUTPUT:
%   notional_swaps - [3x1 Vector] The calculated nominal amounts for the 2y, 
%                    6y, and 10y swaps respectively.
% -------------------------------------------------------------------------

    % Step 1: Define the target vector (b)
    target_b = -coarse.DV01(:);

    % Step 2: Solve the linear system A * x = b
    notional_swaps = delta_NPV'\ target_b;

end