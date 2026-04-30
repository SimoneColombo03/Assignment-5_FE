function plot_spot_vol_surface(spot_vols_matrix, flat_vols, spot_vol_parameters, filename)
% PLOT_SPOT_VOL_SURFACE - Plots and exports the Caplet Spot Volatility Surface.
%
% This function creates a high-quality 3D surface plot representing the 
% term structure and strike skew of the bootstrapped caplet volatilities.
% It automatically exports the figure as a vector-based PDF.
%
% INPUTS:
%   spot_vols_matrix    - [M x S] Matrix of caplet spot volatilities (Decimal).
%   flat_vols           - [Struct] Market data used to extract the strikes.
%   spot_vol_parameters - [Struct] Used to extract the Time to Expiry grid.
%   filename            - [String] Name of the output PDF (e.g., 'VolSurface.pdf').

    % Set default filename if not provided
    if nargin < 4 || isempty(filename)
        filename = 'Spot_Volatility_Surface.pdf';
    end

    % --- 1. Data Preparation ---
    % Extract X-axis (Time to Expiry in Years)
    T_expiry = spot_vol_parameters.T_expiry(:);
    
    % Extract Y-axis (Strikes). Convert to percentages for readability.
    strikes = flat_vols.strike(:) * 100; 
    
    % Prepare Z-axis (Volatilities). Convert decimal to percentages.
    vols_pct = spot_vols_matrix * 100;

    % Create the 2D grid required by MATLAB's surf() function
    [StrikeGrid, TimeGrid] = meshgrid(strikes, T_expiry);

    % --- 2. Figure Creation & Formatting ---
    % Initialize figure with a clean white background and standard size
    fig = figure('Name', 'Caplet Spot Volatility', 'Color', 'w', ...
                 'Position', [100, 100, 800, 600]);

    % Generate the 3D surface plot
    % FaceAlpha adds slight transparency to see grid lines better
    surf(TimeGrid, StrikeGrid, vols_pct, ...
         'FaceAlpha', 0.85, 'EdgeColor', 'interp');

    % Set titles and axis labels
    title('Bootstrapped Caplet Spot Volatility Surface', ...
          'FontSize', 14, 'FontWeight', 'bold');
    xlabel('Time to Expiry (Years)', 'FontSize', 11, 'FontWeight', 'bold');
    ylabel('Strike (%)', 'FontSize', 11, 'FontWeight', 'bold');
    zlabel('Spot Volatility (%)', 'FontSize', 11, 'FontWeight', 'bold');

    % Visual enhancements
    grid on;
    view(-45, 35);            % Adjust viewing angle for best 3D perspective
    colormap('parula');       % Modern MATLAB colormap
    cb = colorbar;            % Add a legend for the colors
    cb.Label.String = 'Volatility (%)';

    % --- 3. PDF Export ---
    try
        exportgraphics(fig, filename, 'ContentType', 'vector', ...
                       'BackgroundColor', 'none');
        fprintf('--- Volatility Surface successfully exported to: %s ---\n', filename);
    catch ME
        warning('plot_spot_vol_surface:ExportFailed', ...
                'Failed to export PDF. Error: %s', ME.message);
    end
end