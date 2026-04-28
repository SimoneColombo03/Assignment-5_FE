function X_percentage = compute_upfront_x(startDate, maturity_unadj,...
    vols, divs, rho, dates, discounts, alpha, P, spread, numSim)
% COMPUTE_UPFRONT_X Calculates the upfront X% for the certificate

% INPUTS:
%   startDate        : Date when performance starts and X is paid
%   maturity_unadj   : Maturity date of the certificate
%   vols             : Volatilities [sigma_E; sigma_AXA]
%   divs             : Dividend yields [d_E; d_AXA]
%   rho              : Correlation coefficient
%   dates            : Bootstrap curve dates
%   discounts        : Bootstrap curve discount factors
%   alpha            : Participation coefficient
%   P                : Protection level 
%   spread           : Spread over Euribor
%   numSim           : Number of Monte Carlo simulations
%
% OUTPUT:
%   X_percentage     : Upfront as a percentage (X%)
    
    % We compute the adjusted maturity (following convention)
    maturity = business_date_offset(maturity_unadj);

    % We compute the discount factors for maturity
    df_mat   = get_discount_factor_by_zero_rates_linear_interp(startDate, maturity, dates, discounts);

    %% PARTY A (Bank XX) 
    
    % We calculate the BPV for the floating leg
    BPV_float = BasisPointValueFloating(startDate, maturity_unadj, dates, discounts);
    
    % We compute the unitary NPV of the floating leg:
    % NPV of the Euribor + NPV of Spread Leg 
    NPV_PartyA_Float = (1 - df_mat) + (spread * BPV_float);
    
    % We compute the NPV of the capital Protection Component
    NPV_PartyA_Prot = (1 - P)* df_mat;
   
    % Total NPV without considering the principal amount
    NPV_PartyA = NPV_PartyA_Float + NPV_PartyA_Prot;
     
    %% PARTY B ( I.B.)
    % Run Monte Carlo simulation for computing the coupon price 
    % without considering the principal amount
    NPV_Coupon = price_basket_coupon_mc(startDate, maturity, ...
               vols, divs, rho, dates, discounts, alpha, P, numSim);
    
    %% X (UPFRONT)
    % X such that NPV_PartyA = X + NPV_Coupon
    X = (NPV_PartyA - NPV_Coupon);
    
    % Return X in percentage
    X_percentage = X * 100;

end