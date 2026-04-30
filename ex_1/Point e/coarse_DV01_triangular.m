function coarse = coarse_DV01_triangular(datesSet, ratesSet, flat_vols, ...
                                          spot_vols_matrix, strike_grid, ...
                                          notional, start_date, maturity_date_unadj, ...
                                          first_coupon_rate, mode_after_6y, ...
                                          X_base)

% COARSE_DV01_TRIANGULAR  Coarse-grained DV01 of the structured bond using
% three TRIANGULAR/RAMP shift profiles centred on 2y, 6y and 10y.
%
%   For each coarse bucket b (0-2y, 2-6y, 6-10y) we build a triangular
%   weight vector w_b on the bootstrap instruments' maturities and feed it
%   directly to bootstrap.m via the 'shift' struct (a +1bp parallel shift
%   re-shaped by the triangle). One bootstrap + repricing per bucket gives
%   the bucket DV01 directly:
%
%       coarse_DV01_b = -(X_b - X_base) * notional
%
%   Weight definition (yf in years, Act/365):
%       w_{0-2y}(yf)  = 1                  for yf <= 2
%                     = (6 - yf)/4         for 2 <  yf <= 6
%                     = 0                  for yf >  6
%
%       w_{2-6y}(yf)  = 0                  for yf <= 2 or yf > 10
%                     = (yf - 2)/4         for 2 <  yf <= 6
%                     = (10 - yf)/4        for 6 <  yf <= 10
%
%       w_{6-10y}(yf) = 0                  for yf <= 6
%                     = (yf - 6)/4         for 6 <  yf <= 10
%                     = 1                  for yf > 10
%
%   The three weights sum to 1 at every maturity, so summing the three
%   coarse DV01s reproduces the parallel +1bp DV01 (up to second-order
%   non-linearity).
%
%   INPUTS:  same as compute_DV01_buckets (plus X_base passed from outside).
%
%   OUTPUT struct with fields:
%      .name      - {'0-2y', '2-6y', '6-10y'}
%      .DV01      - [3 x 1] EUR per coarse bucket (Bank XX side)
%      .shift_struct - cell {3 x 1} of the shift structs used (debug/inspection)

    DC_ACT365 = 3;

    % Maturity (Act/365 yfrac) of every instrument in the bootstrap input.
    % Note: we compute weights for ALL instruments, including those that
    % bootstrap.m may skip (e.g. swaps with maturity already covered by
    % futures). Bumping a skipped instrument has zero effect, so it does
    % not pollute the result.
    yf_depos   = yearfrac(datesSet.settlement, datesSet.depos,        DC_ACT365);
    yf_futures = yearfrac(datesSet.settlement, datesSet.futures(:,2), DC_ACT365);
    yf_swaps   = yearfrac(datesSet.settlement, datesSet.swaps,        DC_ACT365);

    % Triangle weights on each instrument category
    W_depos   = triangular_weights(yf_depos);
    W_futures = triangular_weights(yf_futures);
    W_swaps   = triangular_weights(yf_swaps);

    bucket_names = {'0-2y', '2-6y', '6-10y'};
    DV01         = zeros(3, 1);
    shift_used   = cell(3, 1);

    for b = 1:3
        shift = struct( ...
            'depos',   W_depos(:, b),    ...   % +1bp scaled by triangle
            'futures', W_futures(:, b),  ...
            'swaps',   W_swaps(:, b)     );

        [dates_b, discounts_b, ~] = bootstrap(datesSet, ratesSet, shift);
        spot_vol_parameters_b     = compute_caplets_maturities( ...
                                        flat_vols, dates_b, discounts_b);

        X_b = compute_upfront(notional, ...
                              spot_vols_matrix, strike_grid, ...
                              spot_vol_parameters_b, ...
                              dates_b, discounts_b, ...
                              start_date, maturity_date_unadj, ...
                              first_coupon_rate, mode_after_6y);

        DV01(b)       = -(X_b - X_base) * notional;
        shift_used{b} = shift;
        if b == 1
            coarse.discounts_2y_bucket = discounts_b;
        elseif b == 2
            coarse.discunts_6y_bucket = discounts_b;
        else
            coarse.discounts_10y_bucket = discounts_b; 
        end

    end

    coarse.name         = bucket_names;
    coarse.DV01         = DV01;
    coarse.shift_struct = shift_used;
end


function W = triangular_weights(yf)
% Return [n x 3] of triangular/ramp weights per the convention above.
    yf = yf(:);
    n  = numel(yf);
    W  = zeros(n, 3);

    % Bucket 1: 0-2y -- flat 1 then ramp down to 0 at 6y
    W(:, 1)        = max(0, min(1, (6 - yf) / 4));
    W(yf <= 2, 1)  = 1;

    % Bucket 2: 2-6y -- triangle peaking at 6y
    in_up   = yf > 2  & yf <= 6;
    in_down = yf > 6  & yf <= 10;
    W(in_up,   2) = (yf(in_up)   - 2) / 4;
    W(in_down, 2) = (10 - yf(in_down)) / 4;

    % Bucket 3: 6-10y -- ramp up from 6y to 10y, then flat 1
    W(:, 3)        = max(0, min(1, (yf - 6) / 4));
    W(yf >= 10, 3) = 1;
end