function bucket = compute_DV01_buckets(datesSet, ratesSet, ...
                                       spot_vols_matrix, strike_grid, ...
                                       flat_vols, ...
                                       notional, start_date, maturity_date_unadj, ...
                                       first_coupon_rate, mode_after_6y, ...
                                       X_base)

% COMPUTE_DV01_BUCKETS  Per-instrument delta-bucket sensitivities of the
% structured bond. Every quoted bootstrap instrument is bumped by +1bp via
% the shift-struct interface of bootstrap.m; the curve is re-bootstrapped,
% the bond is re-priced with FROZEN spot vols ("sticky-strike"), and the
% MTM change of Bank XX is reported.
%
%   The base discount curve and base upfront are passed from outside (they
%   are already computed by the main script). The base spot_vol_parameters
%   are NOT passed because they are only used to define X_base, not in the
%   loop.
%
%   Bucket masks mirror those inside bootstrap.m:
%        depos_used   :  maturity   <= first futures settle date
%        futures_used :  expiry     <= 2Y swap maturity
%        swaps_used   :  maturity   >= 2Y swap maturity
%   The 2Y swap is in the swap mask but bootstrap.m skips it (futures
%   already cover it), so its DV01 is exactly 0 (sanity check, not a bug).

    DC_ACT365 = 3;

    % ---------------------------------------------------------------------
    % 1. Identify instruments used in the bootstrap
    % ---------------------------------------------------------------------
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

    % ---------------------------------------------------------------------
    % 2. Build the instrument table
    % ---------------------------------------------------------------------
    label   = cell(n_total, 1);
    group   = cell(n_total, 1);
    grp_idx = zeros(n_total, 1);
    mat_dn  = zeros(n_total, 1);

    p = 0;
    for i = 1:n_d
        p = p + 1;
        label{p}   = sprintf('Depo_%d', idx_depo(i));
        group{p}   = 'depo';
        grp_idx(p) = idx_depo(i);
        mat_dn(p)  = datesSet.depos(idx_depo(i));
    end
    for i = 1:n_f
        p = p + 1;
        label{p}   = sprintf('Fut_%d', idx_fut(i));
        group{p}   = 'future';
        grp_idx(p) = idx_fut(i);
        mat_dn(p)  = datesSet.futures(idx_fut(i), 2);
    end
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

    % ---------------------------------------------------------------------
    % 3. Bump-and-revalue loop  (forward differences, vols frozen)
    %    Uses the shift-struct interface of bootstrap.m: a single bp on a
    %    single instrument.
    % ---------------------------------------------------------------------
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

        [dates_k, discounts_k, ~] = bootstrap(datesSet, ratesSet, shift);
        spot_vol_parameters_k     = compute_caplets_maturities(flat_vols, dates_k, discounts_k);

        X_k = compute_upfront(notional, ...
                              spot_vols_matrix, strike_grid, ...
                              spot_vol_parameters_k, ...
                              dates_k, discounts_k, ...
                              start_date, maturity_date_unadj, ...
                              first_coupon_rate, mode_after_6y);

        delta_X(k) = X_k - X_base;
    end

    % MTM change for Bank XX (locked X*N, fair X moves):
    %   NPV_XX(bumped) - NPV_XX(base) = -(X_bumped - X_base) * N
    DV01_XX = -delta_X * notional;

    % ---------------------------------------------------------------------
    % 4. Parallel +1bp shift (sanity check vs sum of fine-grained DV01)
    % ---------------------------------------------------------------------
    [dates_p, discounts_p, ~] = bootstrap(datesSet, ratesSet, 1);
    spot_vol_parameters_p     = compute_caplets_maturities(flat_vols, dates_p, discounts_p);
    X_p = compute_upfront(notional, ...
                          spot_vols_matrix, strike_grid, ...
                          spot_vol_parameters_p, ...
                          dates_p, discounts_p, ...
                          start_date, maturity_date_unadj, ...
                          first_coupon_rate, mode_after_6y);
    parallel_DV01_XX = -(X_p - X_base) * notional;

    % ---------------------------------------------------------------------
    % 5. Pack output (fine-grained: one row per quoted instrument)
    % ---------------------------------------------------------------------
    bucket.label             = label;
    bucket.group             = group;
    bucket.grp_idx           = grp_idx;
    bucket.maturity          = mat_dn;
    bucket.yf_maturity       = yf_mat;
    bucket.DV01_XX           = DV01_XX;
    bucket.delta_X_pct       = delta_X * 100;       % kept for print compatibility

    bucket.total_DV01_XX     = sum(DV01_XX);
    bucket.parallel_DV01_XX  = parallel_DV01_XX;
    bucket.X_base            = X_base;
end