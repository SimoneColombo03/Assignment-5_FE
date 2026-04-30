% runAssignment5
% group 5, AY2025-2026
%

addpath('bootstrap',genpath('ex_1'),'ex_2');
formatData='dd/mm/yyyy';
[datesSet, ratesSet] = readExcelData_jack('MktData_CurveBootstrap.xls', formatData);
[dates, discounts, ~] = bootstrap(datesSet, ratesSet); 
flat_vols = readCapVols('flat_vol_data.xlsx');


%% Case study 1
%% a. Calibration spot volatilities
spot_vol_parameters = compute_caplets_maturities(flat_vols, dates, discounts);


spot_vols_matrix = compute_spot_vols_Eur_3m(flat_vols,spot_vol_parameters);

%% b. Upfront X% of the structured bond
notional          = 50e6;
first_coupon_rate = 0.04;
mode_after_6y     = 'cap';        % or 'digital'
 
start_date    = datenum('19/02/2008', formatData);
maturity_date_unadj = start_date +datenum(years(10));
 
[X,pv_A,pv_B] = compute_upfront(notional, ...
                    spot_vols_matrix, flat_vols.strike(:), ...
                    spot_vol_parameters,...
                    dates, discounts, ...
                    start_date, maturity_date_unadj, ...
                    first_coupon_rate, mode_after_6y);

fprintf('\n----- POINT (b) Structured bond upfront -----\n');
fprintf('  Mode (after 6y branch) : %s\n', mode_after_6y);
fprintf('  Upfront X              : %.4f%%  of notional\n', X*100);
fprintf('  Upfront amount         : %.2f EUR\n', X*notional);

%% c. Delta-bucket sensitivities (+1bp on each market instrument)
bucket = compute_DV01_buckets(datesSet, ratesSet, ...
                              spot_vols_matrix, flat_vols.strike(:), ...
                              flat_vols, ...
                              notional, start_date, maturity_date_unadj, ...
                              first_coupon_rate, mode_after_6y,X);
print_DV01_buckets(bucket);

%% d. Compute total Vega

vega = compute_total_vega(dates, discounts, flat_vols, notional, start_date, maturity_date_unadj, ...
                           first_coupon_rate, mode_after_6y,spot_vol_parameters,X);
fprintf('Total Vega: %.4f\n', vega);

%% e. Coarse-grained DV01 (3 triangular bumps centred on 2y, 6y, 10y) and hedging with swaps

coarse = coarse_DV01_triangular(datesSet, ratesSet, flat_vols, ...
                                 spot_vols_matrix, flat_vols.strike(:), ...
                                 notional, start_date, maturity_date_unadj, ...
                                 first_coupon_rate, mode_after_6y, X);

fprintf('\n--- Coarse DV01 (triangular shifts) ---\n');
for b = 1:3
    fprintf('   %-7s : %12.2f EUR\n', coarse.name{b}, coarse.DV01(b));
end
fprintf('   sum     : %12.2f EUR\n', sum(coarse.DV01));
fprintf('   parallel: %12.2f EUR  (sanity check)\n', bucket.parallel_DV01_XX);

% Compute hedge ratios based on the DV01 bucket sensitivities
delta_NPV = compute_delta_NPV_swap(ratesSet,dates,discounts, ...
    start_date,coarse);
notional_swaps = compute_portfolio_hedged_with_swap(coarse,delta_NPV);
fprintf('Hedge Ratios:\n');
disp(notional_swaps);
%% f. Hedge vega with cap
output = coarse_vega(dates, discounts, flat_vols, notional, ...
                                   start_date, maturity_date_unadj, ...
                                   first_coupon_rate, mode_after_6y, ...
                                   spot_vol_parameters, X);
 DV01_cap = compute_delta_NPV_cap(flat_vols,ratesSet,spot_vols_matrix,output,dates, discounts);
 notional_caps = compute_portfolio_hedged_with_cap(output,DV01_cap);
 fprintf('Hedge Ratios:\n');
 disp(notional_caps);

%% g. Correction digital risk


%% Case study 2

v_bmm = calibrate_bmm_vols(spot_vols_matrix, flat_vols.strike(:), ...
                           spot_vol_parameters, 15);

[price, se] = price_exotic_cap_mc(v_bmm, spot_vol_parameters, ...
                                  0.1, 15, 5e-4, 1e5, +1);
