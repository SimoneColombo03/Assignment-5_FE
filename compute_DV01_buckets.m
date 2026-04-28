function bucket = compute_DV01_buckets(datesSet, ratesSet, ...
                                       spot_vols_matrix, strike_grid, ...
                                       flat_vols, ...
                                       notional, start_date, maturity_date, ...
                                       first_coupon_rate, mode_after_6y)

% COMPUTE_DV01_BUCKETS  Per-instrument delta-bucket sensitivities of the
% 10Y structured bond (Strategy "A": every quoted bootstrap instrument
% defines its own bucket).
%
%   For each market instrument actually used in the bootstrap (depos,
%   futures, swaps) we shift its quoted rate by +1bp, re-bootstrap the
%   curve, re-derive caplet forwards & discount factors, and re-price the
%   structured bond with FROZEN spot vols ("sticky-strike" delta). The DV01
%   is the change in MTM from Bank XX's side.
%
%   Bucket masks mirror those inside bootstrap.m -- keep in sync if it
%   changes:
%        depos_used   :  maturity   <= first futures settle date
%        futures_used :  expiry     <= 2Y swap maturity
%        swaps_used   :  maturity   >= 2Y swap maturity
%   The 2Y swap is in the swap mask but bootstrap.m skips it because the
%   futures strip already covers that maturity. Bumping it does NOT move
%   the curve -> its DV01 is exactly 0 (sanity check, not a bug).
%
%   INPUTS:
%   datesSet, ratesSet       market data (rates in DECIMAL form, e.g.
%                            0.0429 for 4.29%; +1bp = +1e-4)
%   spot_vols_matrix         [M x n_strikes] caplet spot vols (FROZEN)
%   strike_grid              [n_strikes x 1] strike grid
%   flat_vols                struct with the cap-vol surface (calendar)
%   notional                 N (EUR, e.g. 50e6)
%   start_date, maturity_date, first_coupon_rate, mode_after_6y
%                            same parameters fed to compute_upfront
%
%   OUTPUT bucket struct with fields:
%      .label, .group, .grp_idx     instrument identifier
%      .maturity, .yf_maturity      datenum + Act/365 yfrac to maturity
%      .DV01_XX                     EUR per +1bp bump (signed, XX side)
%      .bucket_id                   index into bucket.coarse.name
%      .coarse.name, .coarse.DV01_XX
%                                   aggregated 0-2y / 2-6y / 6-10y
%      .tail_DV01_XX                instruments with maturity > 10y
%                                   (should be ~0 -- diagnostic only)
%      .total_DV01_XX               sum of all per-instrument DV01_XX
%      .parallel_DV01_XX            +1bp parallel shift (sanity check)
%      .X_base                      base upfront

    BUMP_DECIMAL = 1e-4;
    DC_ACT365    = 3;

    % ---------------------------------------------------------------------
    % 1. Base curve, base caplet grid, base upfront
    % ---------------------------------------------------------------------
    [dates_b, discounts_b, ~] = bootstrap(datesSet, ratesSet);

    [~, fwd_b, yf_capl, df_capl_b, T_exp, ~] = ...
        compute_caplets_maturities(flat_vols, dates_b, discounts_b);

    X_base = compute_upfront(notional, ...
                             spot_vols_matrix, strike_grid, ...
                             fwd_b, yf_capl, T_exp, df_capl_b, ...
                             dates_b, discounts_b, ...
                             start_date, maturity_date, ...
                             first_coupon_rate, mode_after_6y);

    % ---------------------------------------------------------------------
    % 2. Identify instruments used in the bootstrap (same masks as bootstrap.m)
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
    % 3. Build the instrument table
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
    % 4. Bump-and-revalue loop  (forward differences, vols frozen)
    % ---------------------------------------------------------------------
    delta_X = zeros(n_total, 1);

    for k = 1:n_total

        rs_b = ratesSet;
        switch group{k}
            case 'depo'
                rs_b.depos(grp_idx(k), :)   = ratesSet.depos(grp_idx(k), :)   + BUMP_DECIMAL;
            case 'future'
                rs_b.futures(grp_idx(k), :) = ratesSet.futures(grp_idx(k), :) + BUMP_DECIMAL;
            case 'swap'
                rs_b.swaps(grp_idx(k), :)   = ratesSet.swaps(grp_idx(k), :)   + BUMP_DECIMAL;
        end

        [dates_k, discounts_k, ~] = bootstrap(datesSet, rs_b);

        % Only fwd_libor and df_caplets actually move; the calendar yf_capl
        % and T_exp depend on dates only, not on the curve, so we reuse them.
        [~, fwd_k, ~, df_capl_k, ~, ~] = ...
            compute_caplets_maturities(flat_vols, dates_k, discounts_k);

        X_k = compute_upfront(notional, ...
                              spot_vols_matrix, strike_grid, ...
                              fwd_k, yf_capl, T_exp, df_capl_k, ...
                              dates_k, discounts_k, ...
                              start_date, maturity_date, ...
                              first_coupon_rate, mode_after_6y);

        delta_X(k) = X_k - X_base;
    end

    % MTM change for Bank XX (locked X%, curve moved):
    %   NPV_XX(bumped) - NPV_XX(base) = -(X_bumped - X_base) * N
    DV01_XX = -delta_X * notional;

    % ---------------------------------------------------------------------
    % 5. Aggregate into the coarse buckets requested at point (e)
    %    Convention: lower bound exclusive, upper inclusive. Edges are set
    %    a hair above the integer years (e.g. 10y swap maturity is ~10.008
    %    in Act/365 due to business-day adjustments) so that the named
    %    instrument falls in the named bucket.
    % ---------------------------------------------------------------------
    edges      = [0 2.05 6.05 10.05];
    bucket_nm  = {'0-2y', '2-6y', '6-10y'};
    n_buckets  = numel(bucket_nm);
    coarse_DV  = zeros(n_buckets, 1);
    bucket_id  = zeros(n_total, 1);
    tail_DV    = 0;

    for k = 1:n_total
        placed = false;
        for b = 1:n_buckets
            if yf_mat(k) > edges(b) && yf_mat(k) <= edges(b+1)
                bucket_id(k)  = b;
                coarse_DV(b)  = coarse_DV(b) + DV01_XX(k);
                placed        = true;
                break;
            end
        end
        if ~placed
            tail_DV = tail_DV + DV01_XX(k);    % maturity > 10y
        end
    end

    % ---------------------------------------------------------------------
    % 6. Parallel +1bp shift (sanity check vs sum of bucket DV01s)
    % ---------------------------------------------------------------------
    [dates_p, discounts_p, ~] = bootstrap(datesSet, ratesSet, 1);   % +1bp
    [~, fwd_p, ~, df_capl_p, ~, ~] = ...
        compute_caplets_maturities(flat_vols, dates_p, discounts_p);
    X_p = compute_upfront(notional, ...
                          spot_vols_matrix, strike_grid, ...
                          fwd_p, yf_capl, T_exp, df_capl_p, ...
                          dates_p, discounts_p, ...
                          start_date, maturity_date, ...
                          first_coupon_rate, mode_after_6y);
    parallel_DV01_XX = -(X_p - X_base) * notional;

    % ---------------------------------------------------------------------
    % 7. Pack output
    % ---------------------------------------------------------------------
    bucket.label             = label;
    bucket.group             = group;
    bucket.grp_idx           = grp_idx;
    bucket.maturity          = mat_dn;
    bucket.yf_maturity       = yf_mat;
    bucket.DV01_XX           = DV01_XX;
    bucket.delta_X_pct       = delta_X * 100;       % kept for print compatibility
    bucket.bucket_id         = bucket_id;

    bucket.coarse.name       = bucket_nm;
    bucket.coarse.DV01_XX    = coarse_DV;

    bucket.tail_DV01_XX      = tail_DV;
    bucket.total_DV01_XX     = sum(DV01_XX);
    bucket.parallel_DV01_XX  = parallel_DV01_XX;
    bucket.X_base            = X_base;
end