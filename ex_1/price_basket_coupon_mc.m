function Coupon_PV = price_basket_coupon_mc(startDate, maturityDate, ...
    vols, divs, rho, dates, discounts, alpha, P, numSim)
% PRICE_BASKET_COUPON_MC Prices the Party B Coupon paying via Monte Carlo
%
% INPUTS:
%   startDate     : Start date (19-Feb-2008)
%   maturityDate  : Maturity date
%   vols          : Annualized volatilities [sigma_E; sigma_AXA]
%   divs          : Continuous dividend yields [d_E; d_AXA]
%   rho           : Correlation coefficient between the two assets
%   dates         : Bootstrap curve pillar dates
%   discounts     : Bootstrap curve discount factors
%   alpha         : Participation coefficient 
%   P             : Protection level (Strike price for the performance)
%   numSim        : Number of Monte Carlo simulations
%
% OUTPUT:
%   Coupon_PV     : Net Present Value of the coupon at Start Date

    % We compute the yearfrac from Start Date to Maturity Date 
    yf_start_mat = yearfrac(startDate, maturityDate, 3); % ACT/365
    
    % We find the Discount Factor for Maturity Date 
    df_mat = get_discount_factor_by_zero_rates_linear_interp(startDate, maturityDate, dates, discounts);

    % We compute the risk-free rate for the period [Trade Date, Maturity Date]
    r_mat = -log(df_mat) / yf_start_mat;
    
    % Fix seed for reproducibility
    rng(5)

    % We generate independent standard normal variables
    Z_indep = randn(numSim, 2);

    % We define the correlation matrix R and its lower Cholesky factor L
    R = [1, rho; rho, 1];
    L = chol(R, 'lower');
    
    % We generate correlated normals: Z_corr = L * Z_indep
    Z_corr = (L * Z_indep')';

    % We calculate drift and diffusion components for the period [Start Date, Maturity Date]
    % Drift = (r - d - 0.5 * sigma^2) * T
    drifts = (r_mat - divs - 0.5 * vols.^2) * yf_start_mat;
    % Diffusion = sigma * sqrt(T) * Z
    diffusions = vols .* sqrt(yf_start_mat) .* Z_corr.';
    
    % Asset performance: E_i(T) / E_i(Start) =  exp(drift + diffusion)
    asset_perf = exp(drifts + diffusions);

    % The basket is equally weighted: S(T) = 0.5 * Perf_1 + 0.5 * Perf_2
    S_T = mean(asset_perf, 1);
    
    % Coupon Payoff formula: alpha * max(S(T) - P, 0)
    payoffs = alpha * max(S_T - P, 0);

    % Discount the expected payoff back to Start Date
    Coupon_PV = df_mat * mean(payoffs);
end