% runAssignment5
% group 5, AY2025-2026
%

addpath('bootstrap','ex_1')
formatData='dd/mm/yyyy';
[datesSet, ratesSet] = readExcelData_jack('MktData_CurveBootstrap.xls', formatData);
[dates, discounts, ~] = bootstrap(datesSet, ratesSet); 
flat_vols = readCapVols('flat_vol_data.xlsx');

[caplets_dates, fwd_libor, yf_caplets, df_caplets, T_expiry, r_eff] = ...
    compute_caplets_maturities(flat_vols, dates, discounts);

spot_vols_matrix = compute_spot_vols_Eur_3m(flat_vols, fwd_libor, ...
                                yf_caplets, T_expiry, r_eff);

%% Case study 1

%% a. Upfront X% of the structured bond
notional          = 50e6;
first_coupon_rate = 0.04;
mode_after_6y     = 'cap';        % or 'digital'
 
start_date    = datenum('19/02/2008', formatData);
maturity_date = business_date_offset(start_date, 'year_offset', 10, ...
                                     'convention', 'following');
 
X = compute_upfront(notional, ...
                    spot_vols_matrix, flat_vols.strike(:), ...
                    fwd_libor, yf_caplets, T_expiry, df_caplets, ...
                    dates, discounts, ...
                    start_date, maturity_date, ...
                    first_coupon_rate, mode_after_6y);
 
fprintf('\n----- POINT (b) Structured bond upfront -----\n');
fprintf('  Mode (after 6y branch) : %s\n', mode_after_6y);
fprintf('  Upfront X              : %.4f%%  of notional\n', X*100);
fprintf('  Upfront amount         : %.2f EUR\n', X*notional);

%% c. Delta-bucket sensitivities (+1bp on each market instrument)
bucket = compute_DV01_buckets(datesSet, ratesSet, ...
                              spot_vols_matrix, flat_vols.strike(:), ...
                              flat_vols, ...
                              notional, start_date, maturity_date, ...
                              first_coupon_rate, mode_after_6y);
print_DV01_buckets(bucket);
%% Case study 2
