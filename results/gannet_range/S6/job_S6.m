% Auto-generated Osprey job file
% Generated 2026-09-16 14:38:43
% Do not edit by hand - regenerate from the batch script.

seqType = 'MEGA';
editTarget = {'GABA'};
dataScenario = 'invivo';

files = {'D:\biggaba-osprey-repro\data\S6_MP\S01\S01_GABA_68.dat', 'D:\biggaba-osprey-repro\data\S6_MP\S02\S02_GABA_68.dat', 'D:\biggaba-osprey-repro\data\S6_MP\S03\S03_GABA_68.dat', 'D:\biggaba-osprey-repro\data\S6_MP\S04\S04_GABA_68.dat', 'D:\biggaba-osprey-repro\data\S6_MP\S05\S05_GABA_68.dat', 'D:\biggaba-osprey-repro\data\S6_MP\S06\S06_GABA_68.dat', 'D:\biggaba-osprey-repro\data\S6_MP\S07\S07_GABA_68.dat', 'D:\biggaba-osprey-repro\data\S6_MP\S08\S08_GABA_68.dat', 'D:\biggaba-osprey-repro\data\S6_MP\S09\S09_GABA_68.dat', 'D:\biggaba-osprey-repro\data\S6_MP\S10\S10_GABA_68.dat', 'D:\biggaba-osprey-repro\data\S6_MP\S11\S11_GABA_68.dat', 'D:\biggaba-osprey-repro\data\S6_MP\S12\S12_GABA_68.dat'};
files_ref = {'D:\biggaba-osprey-repro\data\S6_MP\S01\S01_GABA_80_H2O.dat', 'D:\biggaba-osprey-repro\data\S6_MP\S02\S02_GABA_80_H2O.dat', 'D:\biggaba-osprey-repro\data\S6_MP\S03\S03_GABA_80_H2O.dat', 'D:\biggaba-osprey-repro\data\S6_MP\S04\S04_GABA_80_H2O.dat', 'D:\biggaba-osprey-repro\data\S6_MP\S05\S05_GABA_80_H2O.dat', 'D:\biggaba-osprey-repro\data\S6_MP\S06\S06_GABA_80_H2O.dat', 'D:\biggaba-osprey-repro\data\S6_MP\S07\S07_GABA_68_H2O.dat', 'D:\biggaba-osprey-repro\data\S6_MP\S08\S08_GABA_68_H2O.dat', 'D:\biggaba-osprey-repro\data\S6_MP\S09\S09_GABA_68_H2O.dat', 'D:\biggaba-osprey-repro\data\S6_MP\S10\S10_GABA_68_H2O.dat', 'D:\biggaba-osprey-repro\data\S6_MP\S11\S11_GABA_68_H2O.dat', 'D:\biggaba-osprey-repro\data\S6_MP\S12\S12_GABA_68_H2O.dat'};

outputFolder = 'D:\biggaba-osprey-repro\results\gannet_range\S6';

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
