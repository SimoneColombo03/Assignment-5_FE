function bucket = compute_DV01_buckets(datesSet, ratesSet, strike_grid, ...
                                       flat_vols, notional, start_date, maturity_date_unadj, ...
                                       first_coupon_rate, mode_after_6y, ...
                                       X_base)
% COMPUTE_DV01_BUCKETS - Calculates instrument-level Delta sensitivities (DV01).
%
% This function performs a "Bump and Revalue" analysis. It shifts each market 
% instrument used in the bootstrap (Deposits, Futures, Swaps) by +1 basis point, 
% re-bootstraps the curve, and re-prices the structured bond to find the specific 
% sensitivity of the Net Present Value (NPV) to that instrument.
%
% METHODOLOGY:
%   - Sticky-Strike: Spot volatilities remain frozen during the rate bump.
%   - Forward Differences: Sensitivities are calculated as NPV(bumped) - NPV(base).
%   - Bank XX Perspective: Reports the MTM change for the issuer.
%
% INPUTS:
%   datesSet/ratesSet   - [Struct] Market data for bootstrapping the curve.
%   strike_grid         - [Vector] Grid for volatility interpolation.
%   flat_vols           - [Struct] Market vol data (used for valuation dates/grid).
%   notional            - [Scalar] Structured bond principal amount.
%   start_date          - [Scalar] Valuation date (datenum).
%   maturity_date_unadj - [Scalar] Maturity date before business day adjustments.
%   first_coupon_rate   - [Scalar] Fixed rate for the first coupon.
%   mode_after_6y       - [String] Payoff logic ('cap' or 'digital').
%   X_base              - [Scalar] The baseline fair upfront (decimal).
%
% OUTPUT:
%   bucket - [Struct] Results containing:
%       .label             : Instrument names (e.g., 'Swap_10y').
%       .maturity          : Maturity datenums of the instruments.
%       .DV01_XX           : EUR change in NPV per instrument (+1bp shift).
%       .total_DV01_XX     : Sum of all individual instrument DV01s.
%       .parallel_DV01_XX  : DV01 from a single +1bp shift of the whole curve.
% -------------------------------------------------------------------------

    DC_ACT365 = 3; % act/365

    % 1. Identify instruments used in the bootstrap
    % Filters instruments based on the same logic used in the bootstrap function.
    mask_depo = datesSet.depos       <= datesSet.futures(1,1);
    mask_fut  = datesSet.futures(:,2) <= datesSet.swaps(2);
    mask_swap = datesSet.swaps        >= datesSet.swaps(2);
    
    idx_depo = find(mask_depo);
    idx_fut  = find(mask_fut);
    idx_swap = find(mask_swap);
    
    n_d     = numel(idx_depo);
    n_f     = numel(idx_fut);
    n_s     = numel(idx_swap);
    n_total = n_d + n_f + n_s;

    % 2. Build the instrument metadata table
    label   = cell(n_total, 1);
    group   = cell(n_total, 1);
    grp_idx = zeros(n_total, 1);
    mat_dn  = zeros(n_total, 1);
    p = 0;
    
    % Map Deposit labels
    for i = 1:n_d
        p = p + 1;
        label{p}   = sprintf('Depo_%d', idx_depo(i));
        group{p}   = 'depo';
        grp_idx(p) = idx_depo(i);
        mat_dn(p)  = datesSet.depos(idx_depo(i));
    end
    % Map Future labels
    for i = 1:n_f
        p = p + 1;
        label{p}   = sprintf('Fut_%d', idx_fut(i));
        group{p}   = 'future';
        grp_idx(p) = idx_fut(i);
        mat_dn(p)  = datesSet.futures(idx_fut(i), 2);
    end
    % Map Swap labels (calculating maturity in years for the label)
    for i = 1:n_s
        p = p + 1;
        yf_tmp     = yearfrac(datesSet.settlement, ...
                              datesSet.swaps(idx_swap(i)), DC_ACT365);
        label{p}   = sprintf('Swap_%dy', round(yf_tmp));
        group{p}   = 'swap';
        grp_idx(p) = idx_swap(i);
        mat_dn(p)  = datesSet.swaps(idx_swap(i));
    end
    yf_mat = yearfrac(datesSet.settlement, mat_dn, DC_ACT365);

    % 3. Bump-and-revalue loop
    % We iterate through every instrument, applying a +1bp shift individually.
    delta_X = zeros(n_total, 1);
    for k = 1:n_total
        shift = struct();
        switch group{k}
            case 'depo'
                shift.depos               = zeros(numel(datesSet.depos), 1);
                shift.depos(grp_idx(k))   = 1;
            case 'future'
                shift.futures             = zeros(size(datesSet.futures,1), 1);
                shift.futures(grp_idx(k)) = 1;
            case 'swap'
                shift.swaps               = zeros(numel(datesSet.swaps), 1);
                shift.swaps(grp_idx(k))   = 1;
        end
        
        % Re-bootstrap the curve with the shifted instrument
        [dates_k, discounts_k, ~] = bootstrap(datesSet, ratesSet, shift);
        
        % Update spot vol parameters (fixing/payment grid) for the new curve
        spot_vol_parameters_k = compute_caplets_maturities(flat_vols, dates_k, discounts_k);
        
        % Volatility Bootstrapping to extract the new spot volatility matrix
        spot_vols_matrix_k = compute_spot_vols_Eur_3m(flat_vols, spot_vol_parameters_k);
        
        % Re-price the bond upfront (X) under the shifted scenario
        X_k = compute_upfront(notional, ...
                              spot_vols_matrix_k, strike_grid, ...
                              spot_vol_parameters_k, ...
                              dates_k, discounts_k, ...
                              start_date, maturity_date_unadj, ...
                              first_coupon_rate, mode_after_6y);
        delta_X(k) = X_k - X_base;
    end

    % Delta sensitivities
    DV01_XX = -delta_X * notional;

    % 4. Parallel +1bp shift (Sanity Check) 
    % Shifts (+1bp) all instruments simultaneously to verify the additive property of DV01 
    % and redo the procedure above.
    [dates_p, discounts_p, ~] = bootstrap(datesSet, ratesSet, 1);
    spot_vol_parameters_p     = compute_caplets_maturities(flat_vols, dates_p, discounts_p);
    spot_vols_matrix_p = compute_spot_vols_Eur_3m(flat_vols, spot_vol_parameters_p);
    X_p = compute_upfront(notional, ...
                          spot_vols_matrix_p, strike_grid, ...
                          spot_vol_parameters_p, ...
                          dates_p, discounts_p, ...
                          start_date, maturity_date_unadj, ...
                          first_coupon_rate, mode_after_6y);
    parallel_DV01_XX = -(X_p - X_base) * notional;

    % 5. Pack output
    bucket.label             = label;
    bucket.group             = group;
    bucket.grp_idx           = grp_idx;
    bucket.maturity          = mat_dn;
    bucket.yf_maturity       = yf_mat;
    bucket.DV01_XX           = DV01_XX;
    bucket.delta_X_pct       = delta_X * 100;       
    bucket.total_DV01_XX     = sum(DV01_XX);
    bucket.parallel_DV01_XX  = parallel_DV01_XX;
    bucket.X_base            = X_base;
end