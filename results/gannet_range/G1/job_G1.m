% Auto-generated Osprey job file
% Generated 2026-09-14 21:23:31
% Do not edit by hand - regenerate from the batch script.

seqType = 'MEGA';
editTarget = {'GABA'};
dataScenario = 'invivo';

files = {'D:\biggaba-osprey-repro\data\G1_MP\G1_MP\S01\S01_GABA_68.7', 'D:\biggaba-osprey-repro\data\G1_MP\G1_MP\S03\S03_GABA_68.7', 'D:\biggaba-osprey-repro\data\G1_MP\G1_MP\S04\S04_GABA_68.7', 'D:\biggaba-osprey-repro\data\G1_MP\G1_MP\S05\S05_GABA_68.7', 'D:\biggaba-osprey-repro\data\G1_MP\G1_MP\S07\S07_GABA_68.7', 'D:\biggaba-osprey-repro\data\G1_MP\G1_MP\S09\S09_GABA_68.7', 'D:\biggaba-osprey-repro\data\G1_MP\G1_MP\S11\S11_GABA_68.7'};

outputFolder = 'D:\biggaba-osprey-repro\results\gannet_range\G1';

opts.SpecReg = 'RobSpecReg';
opts.SubSpecAlignment.mets = 'L2Norm';
opts.fit.method = 'Osprey';
opts.fit.style = 'Separate';
opts.fit.includeMetabs = {'default'};
opts.fit.coMM3 = '3to2MM';
opts.fit.FWHMcoMM3 = 14;
opts.fit.range = [2.79  4.1];
opts.saveLCM = 0;
opts.savejMRUI = 0;
opts.saveVendor = 0;
opts.saveNII = 0;
opts.savePDF = 0;
