function DV01_cap = compute_delta_NPV_cap(flat_vols, ratesSet, ...
                                          spot_vols_matrix, output, ...
                                          dates, discounts)

% COMPUTE_DELTA_NPV_CAP  Bucketed vega matrix of the two ATM hedging caps
% used to immunise the structured bond's vega risk in point (f).
%
%   The output matrix DV01_cap is 2x2 with the convention:
%       rows    = vega bucket of the bond  (1 = 0-6y, 2 = 6-10y)
%       columns = hedging instrument        (1 = ATM 6y cap, 2 = ATM 10y cap)
%
%   Each entry DV01_cap(i, j) is the change in price of cap j when the flat
%   vol surface is bumped with the triangular profile of bucket i (the
%   same profile already used in coarse_vega for the bond, so that the bond
%   vega and the cap vega are measured under identical perturbations).
%
%   Cap composition (Eur 3m, first deterministic Libor excluded):
%       6y  ATM cap  -->  caplets i = 1..23  (last payment date = 6y)
%       10y ATM cap  -->  caplets i = 1..39  (last payment date = 10y)
%   Each ATM cap is struck at the par swap rate of the corresponding swap.
%
%   Sanity checks expected in the result:
%       * DV01_cap(2, 1) ~ 0   (the 6y cap has no caplet beyond 6y, hence
%                               no exposure to the 6-10y vol bucket);
%       * the matrix is therefore (lower-)triangular in finance terms,
%         which is exactly why the assignment hint says "start hedging
%         the longest cap first".
%
%   INPUTS:
%   flat_vols          - flat vol surface struct (.maturity, .strike, ...)
%   ratesSet           - market rates struct (used only for ATM strikes)
%   spot_vols_matrix   - [79 x 13] base stripped caplet spot vols
%   output             - struct from coarse_vega with fields:
%                          .spot_vols_bump_b1  -- bumped surface, bucket 0-6y
%                          .spot_vols_bump_b2  -- bumped surface, bucket 6-10y
%                        (both are full [79 x 13] matrices, NOT single rows)
%   dates, discounts   - bootstrap curve (frozen, vols only move here)
%
%   OUTPUT:
%   DV01_cap           - 2x2 matrix of cap vegas, layout described above

    % --- ATM strikes = par swap rates of the 6y and 10y swaps -------------
    % We index ratesSet.swaps directly: row 6 -> 6y swap, row 10 -> 10y swap.
    strike_6y  = mean(ratesSet.swaps(6,  :), 2);
    strike_10y = mean(ratesSet.swaps(10, :), 2);

    % --- Caplet stripping grid (frozen: curve and dates do not change here)
    parameters_caplets = compute_caplets_maturities(flat_vols, dates, discounts);

    % --- Number of caplets composing each cap -----------------------------
    % Convention: the i-th caplet (i = 1..M) fixes at t_i and pays at
    % t_{i+1}, on a quarterly grid. Therefore a Y-year cap is the sum of
    % the first (4*Y - 1) caplets in our grid (the first deterministic
    % Libor was excluded in compute_caplets_maturities).
    n_6y  = 4*6  - 1;     %  23 caplets
    n_10y = 4*10 - 1;     %  39 caplets

    % --- BASE prices of the two ATM caps ----------------------------------
    % NOTE: we pass the FULL spot_vols_matrix (79 x 13). cap_increment_price
    % takes care of selecting the right number of caplet rows and of
    % interpolating one Black vol per caplet at the ATM strike via spline
    % across strikes (i.e. one strike-spline per caplet row, not a single
    % flat vol applied to all caplets).
    price_cap_base_6y  = cap_increment_price(flat_vols, spot_vols_matrix, ...
                                              strike_6y,  parameters_caplets, n_6y);
    price_cap_base_10y = cap_increment_price(flat_vols, spot_vols_matrix, ...
                                              strike_10y, parameters_caplets, n_10y);

    % --- BUMPED prices: bucket 1 (0-6y triangular shift on flat vols) -----
    price_cap_1b_6y    = cap_increment_price(flat_vols, output.spot_vols_bump_b1, ...
                                              strike_6y,  parameters_caplets, n_6y);
    price_cap_1b_10y   = cap_increment_price(flat_vols, output.spot_vols_bump_b1, ...
                                              strike_10y, parameters_caplets, n_10y);

    % --- BUMPED prices: bucket 2 (6-10y triangular shift on flat vols) ----
    price_cap_2b_6y    = cap_increment_price(flat_vols, output.spot_vols_bump_b2, ...
                                              strike_6y,  parameters_caplets, n_6y);
    price_cap_2b_10y   = cap_increment_price(flat_vols, output.spot_vols_bump_b2, ...
                                              strike_10y, parameters_caplets, n_10y);

    % --- Assemble the 2x2 vega matrix -------------------------------------
    %  rows    = vega bucket of the bond  (1 = 0-6y, 2 = 6-10y)
    %  columns = hedging instrument        (1 = ATM 6y cap, 2 = ATM 10y cap)
    DV01_cap(1, 1) = price_cap_1b_6y  - price_cap_base_6y;     % bucket 0-6y , cap 6y
    DV01_cap(1, 2) = price_cap_1b_10y - price_cap_base_10y;    % bucket 0-6y , cap 10y
    DV01_cap(2, 1) = price_cap_2b_6y  - price_cap_base_6y;     % bucket 6-10y, cap 6y
    DV01_cap(2, 2) = price_cap_2b_10y - price_cap_base_10y;    % bucket 6-10y, cap 10y

end


function p = cap_increment_price(flat_vols, spot_vols, strike_cap, ...
                                  parameters_caplets, n_caplets)

% CAP_INCREMENT_PRICE  Black-76 price of an ATM cap as the sum of its
% caplet prices. Each caplet uses its OWN Black vol, obtained by spline
% interpolation across the strike grid at the cap's ATM strike.
%
%   The function takes the FULL spot vol matrix (rows = caplets, columns =
%   strikes) and selects internally the first n_caplets rows belonging to
%   the cap. This is the key fix vs. the previous version, which mistakenly
%   passed a single row spot_vols_matrix(idx_y, :) and collapsed all caplet
%   vols into a single scalar.
%
%   INPUTS:
%   flat_vols          - struct, used here only for .strike (column grid)
%   spot_vols          - FULL [M x n_strikes] caplet spot vol matrix
%                        (M = 79 in our setup, n_strikes = 13)
%   strike_cap         - scalar ATM strike of the cap
%   parameters_caplets - struct from compute_caplets_maturities with
%                          .fwd_libor, .r_eff, .yf_between_caplets, .T_expiry
%   n_caplets          - number of caplets composing the cap (23 for 6y,
%                        39 for 10y)
%
%   OUTPUT:
%   p                  - cap price per unit notional (sum of Black caplet
%                        prices, each weighted by its delta day-count)

    % --- Slice the caplet grid down to the caplets in this cap -----------
    fwd = parameters_caplets.fwd_libor(1:n_caplets);
    r   = parameters_caplets.r_eff(1:n_caplets);
    yf  = parameters_caplets.yf_between_caplets(1:n_caplets);
    T   = parameters_caplets.T_expiry(1:n_caplets);

    % --- One Black vol per caplet, spline-interpolated across strikes -----
    % For each caplet row i = 1..n_caplets we run a spline interpolation
    % over the strike grid at the (single) ATM cap strike. The result is a
    % column vector of n_caplets distinct Black vols.
    sigma_caplets = arrayfun( ...
        @(i) interp1(flat_vols.strike, spot_vols(i, :), strike_cap, 'spline'), ...
        (1:n_caplets)' );

    % --- Black-76 caplet prices and cap aggregation ----------------------
    % blkprice returns the Black-76 caplet price (one per caplet), already
    % including the discount factor B(t_0, T_{i+1}) implicit through the
    % effective continuous rate r_eff. We weight by the day-count delta_i.
    caplet_prices = blkprice(fwd, strike_cap, r, T, sigma_caplets);
    p             = sum(yf .* caplet_prices);

end