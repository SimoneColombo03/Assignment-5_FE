function print_DV01_buckets(bucket, coarse)
% PRINT_DV01_BUCKETS - Formats and prints the delta sensitivity analysis.
%
% This function displays the results of the DV01 bucket analysis, providing
% a detailed breakdown of how each market instrument (Deposits, Futures, Swaps) 
% contributes to the overall interest rate risk of the structured bond.
%
% INPUTS:
%   bucket - [Struct] Output from compute_DV01_buckets containing:
%               .label            : Instrument identifiers.
%               .group            : Instrument types (depo, future, swap).
%               .yf_maturity      : Maturity expressed in year fractions.
%               .delta_X_pct      : Upfront change as a percentage of Notional.
%               .DV01_XX          : Cash sensitivity for Bank XX (EUR).
%               .total_DV01_XX    : Sum of individual instrument sensitivities.
%               .parallel_DV01_XX : Result of a simultaneous +1bp parallel shift.
%   coarse - [Struct] Optional. Output from coarse_DV01_triangular containing:
%               .name             : Names of the coarse buckets (e.g., 2Y, 6Y, 10Y).
%               .DV01             : Aggregated sensitivities for each bucket.
% -------------------------------------------------------------------------

    % --- Header for Fine-Grained Analysis ---
    fprintf('\n----- POINT (c) Delta-bucket sensitivities (+1bp) -----\n');
    fprintf('%-12s %-7s %8s %14s %14s\n', ...
            'Instrument', 'Group', 'Mat(y)', 'dX (% of N)', 'DV01_XX (EUR)');
    fprintf('%s\n', repmat('-', 1, 60));

    % --- Individual Instrument Rows ---
    for k = 1:numel(bucket.label)
        fprintf('%-12s %-7s %8.3f %14.6f %14.2f\n', ...
                bucket.label{k}, bucket.group{k}, ...
                bucket.yf_maturity(k), ...
                bucket.delta_X_pct(k), ...
                bucket.DV01_XX(k));
    end
    fprintf('%s\n', repmat('-', 1, 60));

    % --- Summary and Sanity Checks ---
    % The total of fine-grained DV01s should be very close to the parallel shift result.
    fprintf('TOTAL (sum of fine-grained DV01)    : %14.2f EUR\n', bucket.total_DV01_XX);
    fprintf('Parallel +1bp shift (sanity check)  : %14.2f EUR\n', bucket.parallel_DV01_XX);
    
    % The Relative Gap highlights potential non-linearities or bootstrapping noise.
    fprintf('Relative gap                        : %14.4f %%\n', ...
            100 * abs(bucket.total_DV01_XX - bucket.parallel_DV01_XX) / ...
                  max(abs(bucket.parallel_DV01_XX), 1));

    % --- Coarse Bucket Analysis ---
    if nargin >= 2 && ~isempty(coarse)
        fprintf('\n--- Coarse buckets (triangular shifts) ---\n');
        for b = 1:numel(coarse.name)
            fprintf('   %-7s : %14.2f EUR\n', coarse.name{b}, coarse.DV01(b));
        end
        fprintf('   %-7s : %14.2f EUR\n', 'sum', sum(coarse.DV01));
    end
    fprintf('\n');
end