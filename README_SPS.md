# Native SPS experiments

Run pe_sps_run in a folder containing pe_sps_run.m, pe_run.m,
pe_sps_rect.m, pe_sps_inv.m, pe_sps_dc.m and pe_draw.m. The models use
Simulink and Simscape Electrical Specialized Power Systems available in
MATLAB R2024b. MATLAB R2026a removed the Specialized Power Systems library.

pe_sps_run() runs all six representative cases. An optional vector limits
the run, for example pe_sps_run([3 4]) runs the two inverters. The latest
archive is pe_physical_results.zip. Each run also retains its own UTC-stamped
folder and ZIP.

The archive contains six model diagrams and matching circuit schematics, the
SLX models with the representative parameters, the corresponding waveforms
and CSV files, the full Simulink trace MAT files, source scripts, summary.csv,
manifest.json, environment.json, and run_log.txt. Partial runs include
available evidence and list unavailable artifacts under failures in
manifest.json. Terminal plots reflect the measured SPS physical circuit.

CSV columns are t_s, channel_1, output_V, current_A and auxiliary. Signal
labels for each experiment are documented in manifest.json. The two
rectifiers export SCR 1's gating pulse on channel 4. The voltage-source
inverter exports both diagonal gate commands on channels 1 and 4. In the
current-source inverter, current_A is the load resistor branch current and
auxiliary is the capacitor branch current.

Measurement windows are two AC fundamental cycles or four DC switching
cycles. Before measurement, the rectifiers warm up for ten AC cycles, the
inverters for six AC cycles, and the buck-boost and Cuk models for 3500
and 9000 switching cycles (175 ms and 450 ms), respectively. The manifest
records the sample step and simulation stop time.
Reference checks compare numerical readings with ideal calculations. Small
differences can result from finite switch resistance and snubber leakage.
The inverter models use synchronously gated native ideal switches, with zero
dead time and no commutation-overlap or reverse-recovery physics.
