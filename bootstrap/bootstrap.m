function [dates, discounts, zeroRates] = bootstrap(datesSet, ratesSet, shift)

% BOOTSTRAP  Constructs a discount factor curve via bootstrapping (vectorised).
%
%   The curve is built in three stages:
%     1) Deposit rates  -- short end of the curve
%     2) Futures rates  -- intermediate maturities (up to the 2Y swap)
%     3) Swap rates     -- long end of the curve
%
%   INPUTS:
%   datesSet   - struct with fields:
%                  .settlement : settlement date (datenum)
%                  .depos      : vector of deposit maturity dates
%                  .futures    : Nx2 matrix [settle_date, expiry_date]
%                  .swaps      : vector of swap maturity dates
%   ratesSet   - struct with fields:
%                  .depos      : Nx2 matrix of deposit rates [BID, ASK]
%                  .futures    : Nx2 matrix of futures rates [BID, ASK]
%                  .swaps      : Nx2 matrix of swap rates    [BID, ASK]
%   shift      - (optional) shift in basis points to apply to the rates.
%                It can be:
%                  * a scalar              -> applied to ALL rates (parallel)
%                  * a struct with fields  -> applied per-category, where
%                      .depos   : column vector, length = numel(datesSet.depos)
%                      .futures : column vector, length = size(datesSet.futures,1)
%                      .swaps   : column vector, length = numel(datesSet.swaps)
%                    Any missing field is treated as zeros. Useful for
%                    instrument-by-instrument bumping (delta-bucket DV01).
%                Default: 0 (no shift).
%
%   OUTPUTS:
%   dates      - vector of dates (settlement at position 1)
%   discounts  - corresponding discount factors (1 at settlement)
%   zeroRates  - corresponding continuously-compounded zero rates (0 at settlement)

if nargin < 3 || isempty(shift)
    shift = 0;
end

% Resolve shift into three column vectors of decimal bumps, one per category.
% For a scalar input we broadcast; for a struct we read each field.
if isstruct(shift)
    bump_depos = get_field_or_zero(shift, 'depos',   numel(datesSet.depos))   * 1e-4;
    bump_fut   = get_field_or_zero(shift, 'futures', size(datesSet.futures,1)) * 1e-4;
    bump_swaps = get_field_or_zero(shift, 'swaps',   numel(datesSet.swaps))   * 1e-4;
else
    bump_depos = shift * 1e-4 * ones(numel(datesSet.depos), 1);
    bump_fut   = shift * 1e-4 * ones(size(datesSet.futures,1), 1);
    bump_swaps = shift * 1e-4 * ones(numel(datesSet.swaps), 1);
end

reference_date = datesSet.settlement;

% Day-count conventions
DC_ACT360 = 2;
DC_30E360 = 6;

%% ========================================================================
%  DEPOS  (vectorised)
%  ========================================================================

mask_depo  = datesSet.depos <= datesSet.futures(1,1);
depo_dates = datesSet.depos(mask_depo);
depo_rates = mean(ratesSet.depos(mask_depo, :), 2) + bump_depos(mask_depo);

yf_depo   = yearfrac(reference_date, depo_dates, DC_ACT360);
B_depo    = 1 ./ (1 + yf_depo .* depo_rates);

dates     = depo_dates;
discounts = B_depo;

%% ========================================================================
%  FUTURES  (vectorised)
%  ========================================================================

mask_fut   = datesSet.futures(:,2) <= datesSet.swaps(2);
fut_settle = datesSet.futures(mask_fut, 1);
fut_expiry = datesSet.futures(mask_fut, 2);
fut_rates  = mean(ratesSet.futures(mask_fut, :), 2) + bump_fut(mask_fut);

yf_fut        = yearfrac(fut_settle, fut_expiry, DC_ACT360);
fwd_discounts = 1 ./ (1 + yf_fut .* fut_rates);

% Vectorised retrieval of discount factor at each futures settle date:
% interp by default, exact on existing pillars.
discount_start           = get_discount_factor_by_zero_rates_linear_interp( ...
                               reference_date, fut_settle, dates, discounts);
[is_match, loc]          = ismember(fut_settle, dates);
discount_start(is_match) = discounts(loc(is_match));

discount_end = fwd_discounts .* discount_start;

dates     = [dates;     fut_expiry];
discounts = [discounts; discount_end];

%% ========================================================================
%  SWAPS  (loop only on swap maturities; everything else vectorised)
%  ========================================================================

% --- Pre-compute the annual coupon grid ONCE (covers every swap) -----------
swap_max         = max(datesSet.swaps);
ref_dt           = datetime(reference_date, 'ConvertFrom', 'datenum');
coupon_dates_all = zeros(0, 1);
for y = 1:60
    d_pay = datenum(ref_dt + calyears(y));
    d_pay = business_date_offset(d_pay, 'convention', 'modified_following');
    coupon_dates_all(end+1, 1) = d_pay;
    if d_pay >= swap_max
        break
    end
end

% Year fractions on the FULL grid: yf_grid(k) = yearfrac(t_{k-1}, t_k)
prev_grid = [reference_date; coupon_dates_all(1:end-1)];
yf_grid   = yearfrac(prev_grid, coupon_dates_all, DC_30E360);

% --- Pre-allocate B_grid and fill points already covered ------------------
n_grid                   = numel(coupon_dates_all);
B_grid                   = get_discount_factor_by_zero_rates_linear_interp( ...
                               reference_date, coupon_dates_all, dates, discounts);
[is_match, loc]          = ismember(coupon_dates_all, dates);
B_grid(is_match)         = discounts(loc(is_match));

% --- Swap selection and rate shift ----------------------------------------
mask_swap  = datesSet.swaps >= datesSet.swaps(2);
swap_dates = datesSet.swaps(mask_swap);
swap_rates = mean(ratesSet.swaps(mask_swap, :), 2) + bump_swaps(mask_swap);

% Maturity-to-grid lookup (tolerance for holiday-calendar mismatches).
[diffs, swap_grid_idx] = min(abs(coupon_dates_all - swap_dates'), [], 1);
swap_grid_idx          = swap_grid_idx(:);
if any(diffs > 4)
    error('Swap maturities not aligned to annual grid (max diff %d days)', max(diffs));
end

% --- Loop on swaps (sequential dependency: B(t0,T_N) becomes a pillar) ----
for k = 1:numel(swap_dates)

    idx_end = swap_grid_idx(k);

    if swap_dates(k) <= dates(end)
        continue
    end

    BPV     = yf_grid(1:idx_end-1)' * B_grid(1:idx_end-1);
    yf_last = yf_grid(idx_end);

    df = (1 - swap_rates(k) * BPV) / (1 + swap_rates(k) * yf_last);

    B_grid(idx_end) = df;

    dates     = [dates;     swap_dates(k)];
    discounts = [discounts; df];
end

%% ========================================================================
%  ZERO RATES
%  ========================================================================

zeroRates = from_discount_factors_to_zero_rates(reference_date, dates, discounts);

dates     = [reference_date; dates];
discounts = [1; discounts];
zeroRates = [0; zeroRates];

end


function v = get_field_or_zero(s, fname, expected_len)
% Return s.(fname) as a column vector of length expected_len.
% If the field is missing, return zeros. If present but wrong-sized, error.
    if isfield(s, fname) && ~isempty(s.(fname))
        v = s.(fname)(:);
        if numel(v) ~= expected_len
            error(['shift.%s has %d elements but the corresponding ' ...
                   'instrument vector has %d.'], fname, numel(v), expected_len);
        end
    else
        v = zeros(expected_len, 1);
    end
end