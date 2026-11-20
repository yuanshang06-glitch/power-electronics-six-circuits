function archive = pe_sps_run(experiments)
%PE_SPS_RUN Run the native SPS circuit models and export the measurements.
%   pe_sps_run() runs all six. pe_sps_run([3 4]) tests only the inverters.
if nargin == 0
    experiments = 1:6;
end
validateattributes(experiments,{'numeric'},{'vector','integer','>=',1,'<=',6,'nonempty'});
archive = pe_run('smoke','sps',unique(experiments(:)'));
end
