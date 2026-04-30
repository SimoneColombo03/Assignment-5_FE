% runAssignment5
% group 5, AY2025-2026
%
% Calibration of spot volatilities on LMM, delta, vega sensitivities of a
% structured bond, delta and vega hedging by using swaps and caps, pricing
% an exoticc cup on a BMM

addpath('bootstrap',genpath('ex_1'),'ex_2');
formatData='dd/mm/yyyy';
[datesSet, ratesSet] = readExcelData_MAC('MktData_CurveBootstrap.xls', formatData);
[dates, discounts, ~] = bootstrap(datesSet, ratesSet); 
flat_vols = readCapVols('flat_vol_data.xlsx');

%% Case study 1
%% a. Calibration spot volatilities
% We build the quarterly Euribor 3M timeline and calculate the implied 
% forward rates and discount factors for each specific caplet period.
spot_vol_parameters = compute_caplets_maturities(flat_vols, dates, discounts);

% Volatility Bootstrapping to extract the specific spot volatility of each caplet from the flat cap quotes.
spot_vols_matrix = compute_spot_vols_Eur_3m(flat_vols, spot_vol_parameters);

% Plot the resulting Caplet Spot Volatility Surface and save it to a PDF.
plot_spot_vol_surface(spot_vols_matrix, flat_vols, spot_vol_parameters, ...
                      'Caplet_Spot_Volatility_Surface.pdf');

%% b. Upfront X% of the structured bond
notional          = 50e6;   %notional
first_coupon_rate = 0.04;   % first coupon rate
mode_after_6y     = 'digital';    
start_date    = datenum('19/02/2008', formatData); %valuation date
maturity_date_unadj = start_date +datenum(years(10)); % unadjusted maturity
 
X = compute_upfront(notional, spot_vols_matrix, flat_vols.strike(:), ...
                    spot_vol_parameters,...
                    dates, discounts, ...
                    start_date, maturity_date_unadj, ...
                    first_coupon_rate, mode_after_6y);

fprintf('\n----- Structured bond upfront -----\n');
fprintf('  Mode (after 6y branch) : %s\n', mode_after_6y);
fprintf('  Upfront X              : %.4f%%  of notional\n', X*100);
fprintf('  Upfront amount         : %.2f EUR\n', X*notional);

%% c. Delta-bucket sensitivities (+1bp on each market instrument)
bucket = compute_DV01_buckets(datesSet, ratesSet, flat_vols.strike(:), ...
                              flat_vols, notional, start_date, maturity_date_unadj, ...
                              first_coupon_rate, mode_after_6y,X);
print_DV01_buckets(bucket);

%% d. Compute total Vega
vega = compute_total_vega(dates, discounts, flat_vols, notional, start_date, maturity_date_unadj, ...
                           first_coupon_rate, mode_after_6y,spot_vol_parameters,X);
fprintf('Total Vega: %.4f\n', vega);

%% e. Coarse-grained DV01 (3 triangular bumps centred on 2y, 6y, 10y) and hedging with swaps
% Calculate Coarse-grained Bucketed DV01
coarse = coarse_DV01_triangular(datesSet, ratesSet, flat_vols, ...
                                 spot_vols_matrix, flat_vols.strike(:), ...
                                 notional, start_date, maturity_date_unadj, ...
                                 first_coupon_rate, mode_after_6y, X);

% Display Coarse DV01 Results
fprintf('\n--- Coarse DV01 (triangular shifts) ---\n');
for b = 1:3
    fprintf('   %-7s : %12.2f EUR\n', coarse.name{b}, coarse.DV01(b));
end

% Sanity Check: The sum of the bucketed DV01s should approximately equal the parallel DV01 
fprintf('   sum     : %12.2f EUR\n', sum(coarse.DV01));
fprintf('   parallel: %12.2f EUR  (sanity check)\n', bucket.parallel_DV01_XX);

% Build the Sensitivity Matrix for Hedging Instruments
delta_NPV = compute_delta_NPV_swap(ratesSet, dates, discounts, start_date, coarse);

% Determine the Swap notionals required to neutralize the portfolio's 
% exposure for every coarse-grained Bucket
notional_swaps = compute_portfolio_hedged_with_swap(coarse, delta_NPV);

% Display Hedging Results
fprintf('\nHedge Ratios (Swap Notionals to buy/sell):\n');
disp(notional_swaps);
%% f. Hedge vega with caps
% Calculate the Structured Bond's Vega for buckets (0-6y and 6-10y).
st_bond_vega_results = compute_st_bond_coarse_vega(dates, discounts, flat_vols, ...
                                             notional, start_date, maturity_date_unadj, ...
                                             first_coupon_rate, mode_after_6y, ...
                                             spot_vol_parameters, X);

% Build the 2x2 Vega sensitivity matrix for the hedging instruments (Caps).
vega_sensitivity_matrix = compute_vega_sensitivity_matrix(flat_vols, ratesSet, ...
                                                          spot_vols_matrix, ...
                                                          st_bond_vega_results, ...
                                                          dates, discounts);

% Find the required hedging nominals.
cap_hedging_notionals = compute_vega_hedge_notionals(st_bond_vega_results, ...
                                                    vega_sensitivity_matrix);

% Display Vega Hedging Results
 fprintf('\nVega Hedging:\n');
 disp(cap_hedging_notionals);

%% g. Correction digital risk

upfront_with_digital_risk = compute_upfront_dig_risk(notional, ...
                                   spot_vols_matrix, flat_vols.strike(:), ...
                                   spot_vol_parameters,...
                                   dates, discounts, ...
                                   start_date, maturity_date_unadj,...
                                   first_coupon_rate, mode_after_6y);

fprintf('\n----- Structured bond upfront with digital risk -----\n');
fprintf('  Mode (after 6y branch) : %s\n', mode_after_6y);
fprintf('  Upfront X              : %.4f%%  of notional\n', upfront_with_digital_risk*100);
fprintf('  Upfront amount         : %.2f EUR\n', upfront_with_digital_risk*notional);

%% Case study 2

v_bmm = calibrate_bmm_vols(spot_vols_matrix, flat_vols.strike(:), ...
                           spot_vol_parameters, 15);

[price, se] = price_exotic_cap_mc(v_bmm, spot_vol_parameters, ...
                                  0.1, 15, 5e-4, 1e5, +1);
fprintf('\n----- Case Study 2: Exotic cap -----\n');
fprintf('Price (per unit notional): %.6f (std err: %.2e)\n', price, se);


[price_V2, se_V2] = price_exotic_cap_V_elisa_mc(v_bmm, spot_vol_parameters, ...
                                  0.1, 15, 5e-4, 1e5, +1);
fprintf('\n----- Case Study 2: Exotic cap -----\n');
fprintf('Price (per unit notional): %.6f (std err: %.2e)\n', price_V2, se_V2);