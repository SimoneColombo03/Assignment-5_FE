function print_DV01_buckets(bucket, coarse)

% PRINT_DV01_BUCKETS  Pretty printer for the output of compute_DV01_buckets.
%
%   Usage:
%       bucket = compute_DV01_buckets(...);
%       coarse = coarse_DV01_triangular(...);             % optional
%       print_DV01_buckets(bucket);                       % fine grid only
%       print_DV01_buckets(bucket, coarse);               % both

    fprintf('\n----- POINT (c) Delta-bucket sensitivities (+1bp) -----\n');
    fprintf('%-12s %-7s %8s %14s %14s\n', ...
            'Instrument', 'Group', 'Mat(y)', 'dX (% of N)', 'DV01_XX (EUR)');
    fprintf('%s\n', repmat('-', 1, 60));

    for k = 1:numel(bucket.label)
        fprintf('%-12s %-7s %8.3f %14.6f %14.2f\n', ...
                bucket.label{k}, bucket.group{k}, ...
                bucket.yf_maturity(k), ...
                bucket.delta_X_pct(k), ...
                bucket.DV01_XX(k));
    end

    fprintf('%s\n', repmat('-', 1, 60));
    fprintf('TOTAL (sum of fine-grained DV01)    : %14.2f EUR\n', bucket.total_DV01_XX);
    fprintf('Parallel +1bp shift (sanity check)  : %14.2f EUR\n', bucket.parallel_DV01_XX);
    fprintf('Relative gap                        : %14.4f %%\n', ...
            100 * abs(bucket.total_DV01_XX - bucket.parallel_DV01_XX) / ...
                  max(abs(bucket.parallel_DV01_XX), 1));

    if nargin >= 2 && ~isempty(coarse)
        fprintf('\n--- Coarse buckets (triangular shifts) ---\n');
        for b = 1:numel(coarse.name)
            fprintf('   %-7s : %14.2f EUR\n', coarse.name{b}, coarse.DV01(b));
        end
        fprintf('   %-7s : %14.2f EUR\n', 'sum', sum(coarse.DV01));
    end

    fprintf('\n');
end