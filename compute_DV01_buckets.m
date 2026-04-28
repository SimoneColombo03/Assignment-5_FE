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
%   structured bond with FROZEN spot vols (standard "delta with fixed
%   vols" convention). The DV01 is the change in MTM from Bank XX's side
%   (i.e. of the structured swap that XX holds on its book).
%
%   The masks of which instruments are "used" mirror the ones inside
%   bootstrap.m and MUST stay in sync if that file changes:
%        depos_used   : maturity   <= first futures settle date
%        futures_used : expiry     <= 2Y swap maturity
%        swaps_used   : maturity   >= 2Y swap maturity
%   Note: the 2Y swap is in the swap mask but is SKIPPED inside the loop
%   because the futures strip already covers it. Its DV01 will be 0 and
%   it is a useful sanity check, not a bug.
%
%   INPUTS
%     datesSet, ratesSet       market data structures (as read from xls).
%                              ratesSet rates are assumed to be in DECIMAL
%                              (e.g. 0.0429 for 4.29%) so that a +1bp bump
%                              equals +1e-4 directly.
%     spot_vols_matrix         [M x n_strikes] LMM/BMM caplet spot vols.
%                              FROZEN throughout the bump loop.
%     strike_grid              [n_strikes x 1] strikes used in stripping.
%     flat_vols                struct with .valuationDate, .maturity, ...
%     notional                 N (in EUR, e.g. 50e6).
%     start_date, maturity_date, first_coupon_rate, mode_after_6y
%                              same parameters fed to compute_upfront.
%
%   OUTPUT
%     bucket struct with fields:
%        .label, .group, .grp_idx     instrument identifier (cell/cell/int)
%        .maturity                    maturity datenum
%        .yf_maturity                 ACT/365 year fraction from settlement
%        .delta_X_bp                  signed change of upfront X (in bp of N)
%                                     = (X_bumped - X_base) * 1e4 / 1
%                                     (basically (X_bp - X_b)*notional in EUR
%                                      after multiplying by N)
%        .DV01_XX                     MTM change of the swap from XX's side
%                                     in EUR for the 1bp bump
%                                     = -(X_bumped - X_base) * N
%        .coarse                      aggregated table:
%                                       .name = {'0-2y','2-6y','6-10y','tail'}
%                                       .DV01_XX (EUR per bucket)
%        .total_DV01_XX               sum of all per-instrument DV01_XX
%        .parallel_DV01_XX            parallel +1bp shift sanity check
%
%   Author: group 5, AY2025-2026.

    % --- Constants ---------------------------------------------------------
    BUMP_DECIMAL = 1e-4;     % +1 basis point in decimal form
    DC_ACT365    = 3;

    % --- 1) Base curve, base caplet grid, base upfront ---------------------
    % Computed once outside the bump loop. We cache only what we need.
    [dates_b, discounts_b, ~] = bootstrap(datesSet, ratesSet);

    [~, fwd_b, yf_capl_b, df_capl_b, T_exp_b, ~] = ...
        compute_caplets_maturities(flat_vols, dates_b, discounts_b);

    X_base = compute_upfront(notional, ...
                             spot_vols_matrix, strike_grid, ...
                             fwd_b, yf_capl_b, T_exp_b, df_capl_b, ...
                             dates_b, discounts_b, ...
                             start_date, maturity_date, ...
                             first_coupon_rate, mode_after_6y);

    % --- 2) Identify instruments used in the bootstrap ---------------------
    % Same masks as bootstrap.m. Keep in sync if bootstrap.m changes.
    mask_depo = datesSet.depos       <= datesSet.futures(1,1);
    mask_fut  = datesSet.futures(:,2) <= datesSet.swaps(2);
    mask_swap = datesSet.swaps        >= datesSet.swaps(2);

    idx_depo = find(mask_depo);
    idx_fut  = find(mask_fut);
    idx_swap = find(mask_swap);

    n_d = numel(idx_depo);
    n_f = numel(idx_fut);
    n_s = numel(idx_swap);
    n_total = n_d + n_f + n_s;

    % --- 3) Build the instrument table -------------------------------------
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
        mat_dn(p)  = datesSet.futures(idx_fut(i), 2);     % expiry date
    end
    for i = 1:n_s
        p = p + 1;
        % Try to give a "Swap_<years>y" label (uses ACT/365 -> rounded year)
        yf_tmp     = yearfrac(datesSet.settlement, ...
                              datesSet.swaps(idx_swap(i)), DC_ACT365);
        label{p}   = sprintf('Swap_%dy', round(yf_tmp));
        group{p}   = 'swap';
        grp_idx(p) = idx_swap(i);
        mat_dn(p)  = datesSet.swaps(idx_swap(i));
    end

    yf_mat = yearfrac(datesSet.settlement, mat_dn, DC_ACT365);

    % --- 4) Bump-and-revalue loop ------------------------------------------
    % Forward difference: re-evaluate at +1bp on a single instrument.
    % Vols are FROZEN: we feed back the same spot_vols_matrix at every step.
    delta_X = zeros(n_total, 1);

    for k = 1:n_total

        % Build a copy of ratesSet with only one row shifted.
        rs_b = ratesSet;
        switch group{k}
            case 'depo'
                rs_b.depos(grp_idx(k), :)   = ratesSet.depos(grp_idx(k), :)   + BUMP_DECIMAL;
            case 'future'
                rs_b.futures(grp_idx(k), :) = ratesSet.futures(grp_idx(k), :) + BUMP_DECIMAL;
            case 'swap'
                rs_b.swaps(grp_idx(k), :)   = ratesSet.swaps(grp_idx(k), :)   + BUMP_DECIMAL;
        end

        % Rebuild curve. The 2Y swap is implicitly skipped inside bootstrap.m
        % (swap maturity already covered by futures), so its bump produces
        % an identical curve and DV01 = 0 -- a sanity check, not a bug.
        [dates_k, discounts_k, ~] = bootstrap(datesSet, rs_b);

        % Re-derive caplet forwards & DFs. Calendar (yf_capl, T_exp) is
        % unchanged, only fwd_libor and df_caplets actually move.
        [~, fwd_k, ~, df_capl_k, ~, ~] = ...
            compute_caplets_maturities(flat_vols, dates_k, discounts_k);

        % Re-price with FROZEN vols. Note: we still need to pass the new
        % yf_capl/T_exp tuples even if numerically identical, because
        % compute_upfront expects them.
        X_k = compute_upfront(notional, ...
                              spot_vols_matrix, strike_grid, ...
                              fwd_k, yf_capl_b, T_exp_b, df_capl_k, ...
                              dates_k, discounts_k, ...
                              start_date, maturity_date, ...
                              first_coupon_rate, mode_after_6y);

        delta_X(k) = X_k - X_base;
    end

    % MTM change for Bank XX (locked X%, bumped curve).
    %     NPV_XX(bumped) = X_base * N + PV_B(bumped) - PV_A(bumped)
    %                    = -(X_bumped - X_base) * N
    DV01_XX = -delta_X * notional;

    % --- 5) Aggregate into the coarse buckets requested at point (e) -------
    % Convention: lower bound exclusive, upper inclusive. SN deposit
    % (yf ~ 0.008y) goes into 0-2y; the 10y swap goes into 6-10y.
    edges      = [0 2 6 10 Inf];
    bucket_nm  = {'0-2y', '2-6y', '6-10y', 'tail (>10y)'};
    n_buckets  = numel(bucket_nm);
    coarseDV   = zeros(n_buckets, 1);
    bucket_id  = zeros(n_total, 1);

    for k = 1:n_total
        for b = 1:n_buckets
            if yf_mat(k) > edges(b) && yf_mat(k) <= edges(b+1)
                bucket_id(k)  = b;
                coarseDV(b)   = coarseDV(b) + DV01_XX(k);
                break;
            end
        end
    end

    % --- 6) Parallel-shift sanity check (optional but cheap) ---------------
    % Shift ALL rates by +1bp at once. If your bootstrap & masks are
    % consistent, this should match sum(DV01_XX) up to second-order
    % non-linearity (typically <1% relative).
    [dates_p, discounts_p, ~] = bootstrap(datesSet, ratesSet, 1);   % +1bp
    [~, fwd_p, ~, df_capl_p, ~, ~] = ...
        compute_caplets_maturities(flat_vols, dates_p, discounts_p);
    X_p = compute_upfront(notional, ...
                          spot_vols_matrix, strike_grid, ...
                          fwd_p, yf_capl_b, T_exp_b, df_capl_p, ...
                          dates_p, discounts_p, ...
                          start_date, maturity_date, ...
                          first_coupon_rate, mode_after_6y);
    parallel_DV01_XX = -(X_p - X_base) * notional;

    % --- 7) Pack output ----------------------------------------------------
    bucket.label             = label;
    bucket.group             = group;
    bucket.grp_idx           = grp_idx;
    bucket.maturity          = mat_dn;
    bucket.yf_maturity       = yf_mat;
    bucket.delta_X_pct       = delta_X * 100;        % in % of N (signed)
    bucket.DV01_XX           = DV01_XX;              % EUR per +1bp
    bucket.bucket_id         = bucket_id;

    bucket.coarse.name       = bucket_nm;
    bucket.coarse.DV01_XX    = coarseDV;

    bucket.total_DV01_XX     = sum(DV01_XX);
    bucket.parallel_DV01_XX  = parallel_DV01_XX;
    bucket.X_base            = X_base;

end
