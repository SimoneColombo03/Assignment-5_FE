function hedging_notionals = compute_vega_hedge_notionals(st_bond_vega_results, vega_sensitivity_matrix)
% COMPUTE_VEGA_HEDGE_NOTIONALS - Calculates the required notionals for Vega hedging.
%
% This function solves the linear system A * x = b, where 'A' is the sensitivity 
% matrix of the hedging instruments (Caps) and 'b' is the target vector 
% representing the exposure of the structured bond's Vega buckets.
%
% INPUTS:
%   st_bond_vega_results    - [Struct] containing vega for each bucket (0-6y and 6-10y )
%   vega_sensitivity_matrix - [2x2 Matrix] Sensitivity of the 6y and 10y Caps 
%                             to the 0-6y and 6-10y volatility buckets
%
% OUTPUT:
%   hedging_notionals       - [Vector] The EUR notionals for the 6y and 10y Caps 
%                             required to achieve a Vega-neutral portfolio

    % Step 1: Define the Target Vector (Right-Hand Side)
    % To hedge the portfolio, the sum of the Vega from the Caps and the structured Bond 
    % must be zero. Thus: Vega_Caps * Notional = -Vega_st_Bond.
    % We take structured bond's bucketed Vega and change the sign to define our target
    % Row 1 corresponds to the 0-6y bucket; Row 2 corresponds to the 6-10y bucket
    target_exposure = [ -st_bond_vega_results.coarse_v(1); ...
                        -st_bond_vega_results.coarse_v(2) ];

    % Step 2: Solve the Linear System
    % If vega_sensitivity_matrix is:
    %   [ V_Cap6_B1,  V_Cap10_B1 ]
    %   [ V_Cap6_B2,  V_Cap10_B2 ]
    % Then hedging_notionals(1) is for the 6y Cap and (2) is for the 10y Cap
    hedging_notionals = vega_sensitivity_matrix \ target_exposure;

end