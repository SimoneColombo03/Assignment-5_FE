function print_DV01_buckets(bucket)
% PRINT_DV01_BUCKETS  Pretty printer for the output of compute_DV01_buckets.
%
%   Usage:
%       bucket = compute_DV01_buckets(...);
%       print_DV01_buckets(bucket);

    fprintf('\n----- POINT (c) Delta-bucket sensitivities (+1bp) -----\n');
    fprintf('%-12s %-7s %8s %14s %14s\n', ...
            'Instrument','Group','Mat(y)','dX (% of N)','DV01_XX (EUR)');
    fprintf('%s\n', repmat('-', 1, 60));

    for k = 1:numel(bucket.label)
        fprintf('%-12s %-7s %8.3f %14.6f %14.2f\n', ...
                bucket.label{k}, bucket.group{k}, ...
                bucket.yf_maturity(k), ...
                bucket.delta_X_pct(k), ...
                bucket.DV01_XX(k));
    end

    fprintf('%s\n', repmat('-', 1, 60));
    fprintf('TOTAL (sum of buckets)              : %14.2f EUR\n', bucket.total_DV01_XX);
    fprintf('Parallel +1bp shift (sanity check)  : %14.2f EUR\n', bucket.parallel_DV01_XX);
    fprintf('Relative gap                        : %14.4f %%\n', ...
            100 * abs(bucket.total_DV01_XX - bucket.parallel_DV01_XX) / ...
                  max(abs(bucket.parallel_DV01_XX), 1));

    fprintf('\n--- Coarse buckets (DV01_XX in EUR) ---\n');
    for b = 1:numel(bucket.coarse.name)
        fprintf('   %-12s : %14.2f\n', bucket.coarse.name{b}, bucket.coarse.DV01_XX(b));
    end
    fprintf('\n');
end
