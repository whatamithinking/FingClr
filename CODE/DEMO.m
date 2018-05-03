
%% INITIALIZE

close all;clc;

UseManualChannelSelections = 0;
NeedDataForPlots = 1;
UseValidationData = 1;  % use outside datasource to show that the model is not just working for this data
NeedToPreprocess = 1;
DemoCNN = 1;
DemoSVM = 1;
RunCount = 1;
TestRatio = 0.25;
ShowModelDemo = 0;
BuildModels = 1;

DataDir = 'C:\Users\conno\OneDrive\Desktop\CODE_VERSION_5\DATA_VERSION_6\EMG';
ValidationDataDir = 'C:\Users\conno\OneDrive\Desktop\CODE_VERSION_5\DATA_VERSION_6\VALIDATION_DATA\Database 1';
ChannelNames = { 'CH1','CH2','CH4','CH5','CH6','CH7' };

if UseValidationData == 0
    % EMG DATA
    [ DimNames, ClassNames, ClassCount, ...
        MaxChCount, FileCount, Data, ChannelDict, ObsPerFile ] = ...
        loadEMGData( DataDir, ChannelNames, UseManualChannelSelections );
    EMGBrainStoreDir = 'C:\Users\conno\OneDrive\Desktop\CODE_VERSION_5\MODELS\CNN\EMG';
    SVMBrainStoreDir = 'C:\Users\conno\OneDrive\Desktop\CODE_VERSION_5\MODELS\SVM\EMG';
    SmplFreq = 960;
    StartFreq = 1;
    StopFreq = 479;
    EpochCount = 600;
    BandStopFreq = 60;
    QuantityPerClass = 0;
    GaussNoiseAmp = 0;
else
    % VALIDATION DATA
    EMGBrainStoreDir = 'C:\Users\conno\OneDrive\Desktop\CODE_VERSION_5\MODELS\CNN\VAL';
    SVMBrainStoreDir = 'C:\Users\conno\OneDrive\Desktop\CODE_VERSION_5\MODELS\SVM\VAL';
    loadValidationData;
    SmplFreq = 500;
    StartFreq = 1;
    StopFreq = 249;
    EpochCount = 400;
    BandStopFreq = 50;
    QuantityPerClass = 100;
    GaussNoiseAmp = 0.03;
end

% FileCount = 1;

if NeedToPreprocess == 1
    %% EXTRACT FEATURES
    [ RawTable, FFTTable, FeaturesTable, NormalizedTable, FeatureCellArray ] = ...
        EMG_CNN.preprocessData( Data, FileCount, MaxChCount, ClassNames, ...
                        ObsPerFile, ChannelNames, SmplFreq, StartFreq, ...
                        StopFreq, BandStopFreq, NeedDataForPlots );
end

if NeedDataForPlots == 1
    
    % PLOT TIME-SERIES CHANNEL AGAINST CHANNEL
    EMG_CNN.plotChlAgainstChl( RawTable, 'CH1', 'CH2', 'Raw Time-Series Plot' )

    % PLOT FREQ CHANNEL AGAINST CHANNEL
    EMG_CNN.plotChlAgainstChl( FFTTable, 'CH1', 'CH2', 'Raw Freq-Domain Plot' )

    % PLOT RAW CHANNEL
    EMG_CNN.plotTIME( RawTable, 'CH1', ObsPerFile, SmplFreq )

    % PLOT SPECTRUM
    EMG_CNN.plotFFT( FFTTable, 'CH1', SmplFreq )

    % PLOT FEATURES
    EMG_CNN.plotFeatureAgainstFeature( FeaturesTable, 'Time_CH1_RMS', 'Time_CH2_RMS', 'Extracted Features Plot' )

    % PLOT NORMALIZED
    EMG_CNN.plotFeatureAgainstFeature( NormalizedTable, 'Time_CH1_RMS', 'Time_CH2_RMS', 'Normalized Extracted Features (NEF) Plot' )
end

%% EMG

if DemoCNN == 1
    
    if BuildModels == 1
        % RUN ENTIRE OVERSAMPLE/TRAINING-TEST SPLIT/MODEL BUILD MULTIPLE TIMES AND GET EXPECTED MODEL
        EMG_CNN.getExpModel( FeatureCellArray, RunCount, EMGBrainStoreDir, TestRatio, ...
                            QuantityPerClass, EpochCount, GaussNoiseAmp, 10, 0.01 );
    end
    if ShowModelDemo == 1
        if UseValidationData==1
            load("C:\Users\conno\OneDrive\Desktop\CODE_VERSION_5\MODELS\CNN\VAL\0_98.mat")
        else
            load("C:\Users\conno\OneDrive\Desktop\CODE_VERSION_5\MODELS\CNN\EMG\0_92241.mat")
        end
        for i=1:5
            iRandSmpl = randperm(size(FeatureCellArray,1));
            Predicted = ConvNet.classify( FeatureCellArray{iRandSmpl(i),1} )
            Actual = FeatureCellArray{iRandSmpl(i),2}
        end
    end
end

%% SVM

if DemoSVM == 1

    if BuildModels == 1
        % GET EXPECTED CLASSIFIER
        EMG_SVM.getExpModel( FeaturesTable, RunCount, SVMBrainStoreDir, 0.25, QuantityPerClass );
    end
    if ShowModelDemo == 1
        if UseValidationData==1
            load("C:\Users\conno\OneDrive\Desktop\CODE_VERSION_5\MODELS\SVM\VAL\0_98667.mat")
        else
            load("C:\Users\conno\OneDrive\Desktop\CODE_VERSION_5\MODELS\SVM\EMG\0_98707.mat")
        end
        for i=1:5
            iRandSmpl = randperm(size(FeaturesTable,1));
            iPredicted = Mdl.predictFcn( FeaturesTable(iRandSmpl(i),1:size(FeaturesTable,2)-1) );
            UniqueClassNames = unique( ClassNames );
            Predicted = UniqueClassNames(iPredicted)
            Actual = string( FeaturesTable{iRandSmpl(i),size(FeaturesTable,2)} )
        end  
    end
end



