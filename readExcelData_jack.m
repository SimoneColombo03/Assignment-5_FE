function [dates, rates] = readExcelData_jack(filename, formatData)
% Reads data from excel
%  It reads bid/ask prices and relevant dates
%  All input rates are in % units
%
% INPUTS:
%  filename: excel file name where data are stored
%  formatData: data format in Excel
%
% OUTPUTS:
%  dates: struct with settlementDate, deposDates, futuresDates, swapDates
%  rates: struct with deposRates, futuresRates, swapRates

%% Dates

% Settlement
settlement = readcell(filename, 'Sheet', 1, 'Range', 'E8');
dates.settlement = toDatenum(settlement{1}, formatData);

% Depos
date_depositi = readcell(filename, 'Sheet', 1, 'Range', 'D11:D18');
dates.depos = cellfun(@(x) toDatenum(x, formatData), date_depositi);

% Futures: start & end
date_futures_read = readcell(filename, 'Sheet', 1, 'Range', 'Q12:R20');
numberFutures = size(date_futures_read, 1);
dates.futures = ones(numberFutures, 2);
dates.futures(:,1) = cellfun(@(x) toDatenum(x, formatData), date_futures_read(:,1));
dates.futures(:,2) = cellfun(@(x) toDatenum(x, formatData), date_futures_read(:,2));

% Swaps
date_swaps = readcell(filename, 'Sheet', 1, 'Range', 'D39:D88');
dates.swaps = cellfun(@(x) toDatenum(x, formatData), date_swaps);

%% Rates (Bids & Asks)

% Depos
tassi_depositi = readmatrix(filename, 'Sheet', 1, 'Range', 'E11:F18');
rates.depos = tassi_depositi / 100;

% Futures
tassi_futures = readmatrix(filename, 'Sheet', 1, 'Range', 'E28:F36');
tassi_futures = 100 - tassi_futures;
rates.futures = tassi_futures / 100;

% Swaps
tassi_swaps = readmatrix(filename, 'Sheet', 1, 'Range', 'E39:F88');
rates.swaps = tassi_swaps / 100;

end

%% Helper function
function dn = toDatenum(val, fmt)
    if isdatetime(val)
        dn = datenum(val);
    elseif ischar(val) || isstring(val)
        dn = datenum(val, fmt);
    else
        error('Formato data non riconosciuto');
    end
end