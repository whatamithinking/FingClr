classdef EMG_CNN
methods( Static )
function getExpModel( FeatureCellArray, RunCount, MdlSaveDir, ...
            TestRatio, QuantityPerClass, EpochCount,...
            GaussNoiseAmp, LayerCount, LearningRate )

    TrainExp = [];
    TrainPred = [];
    ValidationExp = [];
    ValidationPred = [];
    TestExp = [];
    TestPred = [];
    
    ExpMdlProgressBar = waitbar( 0, 'Calculating Expected Model...' );

    %% OVERSAMPLE TO AVOID BIAS ( IN CASE SOME CLASSES HAVE MORE DATA THAN OTHERS )
    [ OversampledMatrix, OM_ClassNames ] = EMG_CNN.getOversampledData( FeatureCellArray, QuantityPerClass );
    
    for run=1:RunCount

        %% GET TRAINING / TESTING / VALIDATION DATA
        [ TrainingMatrix, TestingMatrix, TrainingClassNames, TestingClassNames  ] = ...
            EMG_CNN.getSampleData( OversampledMatrix, TestRatio, OM_ClassNames );

        %% BUILD / TRAIN MODEL with train/validation data
        [ConvNet,TrainInfo] = EMG_CNN.buildModel( EpochCount, MdlSaveDir, ...
                                TrainingMatrix, GaussNoiseAmp, 1, LayerCount, LearningRate );

        %% GET TRAIN RESULTS
        TrainPredictions = classify( ConvNet, TrainingMatrix(:,1:size(TrainingMatrix,2)-1) );
        TrainPred = [ TrainPred; TrainPredictions ];
        TrainExp = [ TrainExp; TrainingMatrix(:,size(TrainingMatrix,2)) ];

        %% GET TEST RESULTS
        TestPredictions = classify( ConvNet, TestingMatrix(:,1:size(TestingMatrix,2)-1) );
        TestPred = [ TestPred; TestPredictions ];
        TestExp = [ TestExp; TestingMatrix(:,size(TestingMatrix,2)) ];

        %% SAVE MODEL IF GOOD ACCURACY
        ConfMatrix = confusionmat( string( TestingMatrix(:,size(TestingMatrix,2)) ), string( TestPredictions ) );
        ConfMatrixAccuracy = ConfMatrix ./ sum( ConfMatrix' )';
        ClassCount = size( unique(TestingMatrix(:,size(TestingMatrix,2))),1 );
        TestAccuracy = sum( diag( ConfMatrixAccuracy ) ) / ClassCount;
        if TestAccuracy >= 0.9  % save model if accuracy good enough
            FileName = strrep( strcat( MdlSaveDir,'\', ...
                            num2str( TestAccuracy ) ), '.','_' );
            save(FileName,'ConvNet');
        end

        % UPDATE PROGRESS
        waitbar( run/RunCount, ExpMdlProgressBar )

    end
    close( ExpMdlProgressBar )

    % BUID CONFUSION MATRICES
    EMG_CNN.showResults( string( TrainPred ), string( TrainExp ), 'Training ' )
    EMG_CNN.showResults( string( TestPred), string( TestExp ), 'Testing ' )

end

function [ RawTable, FFTs, Features, Normalized, NormalCellArray ] = ...
            preprocessData( Data, FileCount, MaxChCount, ClassNames, ...
                            ObsPerFile, ChannelNames, SmplFreq, StartFreq,...
                            StopFreq, BandStopFreq, NeedDataForPlots )

    ExtractedFeatureCount = 8;

    % BUILD TABLE/MATRIX FOR EACH STEP OF THE PROCESS
    ClassNames_ObsPerFile = strings( ObsPerFile, 1 );

    % RAW TIME-SERIES DATA. JUST A STREAM FOR EACH CHANNEL
    RawTable = [];
    RawData_ClassNames = {};

    % FREQUENCY-DOMAIN DATA
    FFTs=[];

    % EXTRACTED FEATURES, WITH EACH COLUMN A FEATURE FOR A SPECIFIC CHANNEL
    Features = [];
    Features_ClassNames = {};

    % THE NORMALIZED EXTRACTED FEATURES. EACH COLUMN A FEATURE FOR A
    % CHANNEL. EACH ROW IS ONE OBSERVATION
    Normalized = [];

    % THE OUTPUTTED DATA. CELL ARRAY. EACH CELL CONTAINS A ( CHANNEL COUNT
    % by EXTRACTED FEATURE COUNT ) MATRIX
    NormalCellArray = cellmat( FileCount, 1, MaxChCount, ExtractedFeatureCount );

    FileReadProgressBar = waitbar( 0, 'Preprocessing Data...' );
    for iFile = 1 : FileCount

        % GET TABLE OF DATA
        ClassName = char( ClassNames( iFile, 1 ) );
        if isa( Data, 'matlab.io.datastore.SpreadsheetDatastore' )
            FilePath = Data.Files{ iFile };
            DataTable = read( Data );
        else % if cell array, then just pull data directly
            DataTable = array2table( Data{iFile,1} );
            DataTable.Properties.VariableNames = reshape( ChannelNames, [ size(ChannelNames,2), 1 ] );
        end

        if NeedDataForPlots == 1
            % SAVE RAW DATA
            ClassNames_ObsPerFile(:,:) = ClassName;
            TempDataTable = DataTable;
            TempDataTable.Class = ClassNames_ObsPerFile;
            RawTable = [ RawTable; TempDataTable ];
        end

        % EXTRACT FEATURES
        [ RowTempTable, ArrayTempTable, FFTTable ] = EMG_CNN.extractFeatures( ...
            DataTable, SmplFreq, StartFreq, StopFreq, BandStopFreq, ChannelNames );
        TempMatrix = table2array( ArrayTempTable );
        RotTempMatrix = rot90( TempMatrix, 1 );

        if NeedDataForPlots == 1
            % SAVE FFT TABLE
            FFTTempStrArr = strings( size(FFTTable,1), 1 );
            FFTTempStrArr(:,:) = ClassName;
            FFTTable.Class = FFTTempStrArr;
            FFTs = [ FFTs; FFTTable ];

            % SAVE EXTRACTED FEATURES
            Features = [ Features; RowTempTable ];
            Features_ClassNames = [ Features_ClassNames; ClassName ];
        end

        % NORMALIZE
        NormMatrix = RotTempMatrix - min(RotTempMatrix(:));
        NormMatrix = NormMatrix ./ max(NormMatrix(:));
        NormalCellArray{ iFile, 1 } =  NormMatrix;
        NormalCellArray{ iFile, 2 } = ClassName;

        if NeedDataForPlots == 1
            % SAVE NORMALIZED DATA
            TableColNames = RowTempTable.Properties.VariableNames;
            NormArray = table2array( RowTempTable );
            NewNormMatrix = NormArray - min( NormArray(:) );
            NewNormMatrix = NewNormMatrix ./ max( NewNormMatrix(:,:) );
            NormTable = array2table( NewNormMatrix );
            NormTable.Properties.VariableNames = TableColNames;
            Normalized = [ Normalized; NormTable ];
        end

        % UPDATE PROGRESS
        waitbar( iFile/FileCount, FileReadProgressBar )

    end
    close( FileReadProgressBar )

    % BUILD OUTPUTS
    Features.Class = Features_ClassNames;
    Normalized.Class = Features_ClassNames;

end

function [ConvNet,TrainInfo] = buildModel( ...
            MaxEpochs, CheckpointPath, TrainingMatrix, ...
            GaussNoiseAmp, PlotTraining, LayerCount, LearningRate )

    % build layers and set options for model
    UniqueClassNames = string( unique( TrainingMatrix(:,size(TrainingMatrix,2)) ) );
    ClassCount = size( UniqueClassNames, 1 );
    MaxChCount = size( TrainingMatrix{1,1}, 1 );
    ConvNet = [...
        sequenceInputLayer( MaxChCount )
        bilstmLayer( LayerCount,'OutputMode','last' )
        fullyConnectedLayer( ClassCount )
        softmaxLayer
        classificationLayer
    ];
    if PlotTraining == 1
        options = trainingOptions('adam', ...
            'MaxEpochs',MaxEpochs, ...
            'MiniBatchSize', 150, ...
            'LearnRateDropPeriod',1,...
            'LearnRateDropFactor',0.1,...
            'InitialLearnRate', LearningRate, ...
            'plots','training-progress', ...
            'Verbose',false...
            );
    else
        options = trainingOptions('adam', ...
            'MaxEpochs',MaxEpochs, ...
            'MiniBatchSize', 150, ...
            'LearnRateDropPeriod',1,...
            'LearnRateDropFactor',0.1,...
            'InitialLearnRate', LearningRate, ...
            'Verbose',false...
            );
%         'CheckpointPath',CheckpointPath...
    end

    % ADD GAUSSIAN NOISE
    if GaussNoiseAmp > 0
        TrainingMatrix = EMG_CNN.addGaussianNoise( TrainingMatrix, GaussNoiseAmp );
    end

    % TRAIN
    CatClassNames = categorical( string( TrainingMatrix(:,size(TrainingMatrix,2)) ) );
    TempTrainingMatrix = TrainingMatrix(:,1:size(TrainingMatrix,2)-1);
    [ ConvNet, TrainInfo ]= trainNetwork( TempTrainingMatrix...
                                          ,CatClassNames,ConvNet,options );
end

function showResults( Predicted, Expected, Title )
    figure;
    cm = confusionmat( Expected, Predicted );
    oPlot = plotConfMat( cm, unique( Expected ) );
    OldTitle = get( oPlot, 'title' );
    title( strcat( { Title }, { OldTitle.String } ) );    
end

function [ TrainingMatrix, TestingMatrix, TrainingClassNames, TestingClassNames ] = ...
            getSampleData( DataMatrix, TestRatio, ClassNames )

    TrainingMatrix = [];
    TestingMatrix = [];
    TrainingClassNames = {};
    TestingClassNames = {};

    % RANDOM SAMPLE FROM EACH CLASS. ALL CLASSES HAVE TRAIN/TEST SPLIT
    % REQUESTED
    UniqueClassNames = unique( ClassNames );
    for c=1:size( UniqueClassNames, 1 )

        % GET DATA FOR CLASS
        ClassName = UniqueClassNames(c,1);
        ClassData = DataMatrix( ClassNames == ClassName, : );

        % GET INDICES FOR TRAIN/VALIDATE/TEST
        cvp = cvpartition( size( ClassData,1 ), 'HoldOut', TestRatio );
        idxTest = test( cvp );
        idxTrain = training( cvp );

        ClassTrainData = ClassData( idxTrain,: );
        ClassTestData = ClassData( idxTest,: );  
        TempClassNames = strings( size( ClassTrainData,1 ), 1 );
        TempClassNames(:) = ClassName;
        ClassTrainClassNames = TempClassNames;
        TempClassNames = strings( size( ClassTestData,1 ), 1 );
        TempClassNames(:) = ClassName;
        ClassTestClassNames = TempClassNames;
        
        % STORE TO GLOBAL MATRICES FOR ALL CLASSES
        TrainingMatrix = [ TrainingMatrix; ClassTrainData ];
        TestingMatrix = [ TestingMatrix; ClassTestData ];
        TrainingClassNames = [ TrainingClassNames; ClassTrainClassNames ];
        TestingClassNames = [ TestingClassNames; ClassTestClassNames ];
        
    end

    % RANDOM SHUFFLE THE DATA
    iRandShfl = randperm( size( TrainingMatrix,1 ) );
    TrainingMatrix = TrainingMatrix( iRandShfl, : );
    TrainingClassNames = TrainingClassNames( iRandShfl );
    iRandShfl = randperm( size( TestingMatrix,1 ) );
    TestingMatrix = TestingMatrix( iRandShfl, : );
    TestingClassNames = TestingClassNames( iRandShfl );
    
end

function [ RowTempTable, ArrayTempTable, FFTTable ]= extractFeatures( ...
            DataTable, SmplFreq, StartFreq, StopFreq, BandStopFreq, ChannelNames )

    % GET TIME-SERIES FEATURES FOR EACH CHANNEL
    Time_ChlMeans = table2array( varfun( @mean, DataTable ) );     
    Time_ChlMaxs = table2array( varfun( @max, DataTable ) );
    Time_ChlVariances = table2array( varfun( @var, DataTable ) );
    Time_Ch1RMS = table2array( varfun( @rms, DataTable ) );

    % GET FREQ-DOMAIN FEATURES FOR EACH CHANNEL
    FFTTable = FFT( DataTable, size( DataTable, 1 ), StartFreq, StopFreq, 1, SmplFreq, BandStopFreq );
    Freq_ChlMeans = table2array( varfun( @mean, FFTTable ) );     
    Freq_ChlMaxs = table2array( varfun( @max, FFTTable ) );
    Freq_ChlVariances = table2array( varfun( @var, FFTTable ) );
    Freq_Ch1RMS = table2array( varfun( @rms, FFTTable ) );

    % CONCAT ALL FEATURES INTO ONE ROW
    ArrayTempMatrix = [ ...
                        Time_ChlMeans...
                        ;Time_ChlMaxs...
                        ;Time_ChlVariances...
                        ;Time_Ch1RMS...
                        ;Freq_ChlMeans...
                        ;Freq_ChlMaxs...
                        ;Freq_ChlVariances...
                        ;Freq_Ch1RMS...
                    ];
    RowTempMatrix = [ ...
                        Time_ChlMeans...
                        ,Time_ChlMaxs...
                        ,Time_ChlVariances...
                        ,Time_Ch1RMS...
                        ,Freq_ChlMeans...
                        ,Freq_ChlMaxs...
                        ,Freq_ChlVariances...
                        ,Freq_Ch1RMS...
                    ];
    FeatureNames = { 'Time_{Chl}_Mean'...
                     ,'Time_{Chl}_Max'...
                     ,'Time_{Chl}_Var'...
                     ,'Time_{Chl}_RMS'...
                     'Freq_{Chl}_Mean'...
                     ,'Freq_{Chl}_Max'...
                     ,'Freq_{Chl}_Var'...
                     ,'Freq_{Chl}_RMS'...
                     };
    RowColumnNames = {};
    for f=1:size(FeatureNames,2)
        for c=1:size(ChannelNames,2)
            NewFeatureName = strrep( FeatureNames(1,f), '{Chl}', strcat( 'CH', num2str( c ) ) );
            RowColumnNames = [ RowColumnNames, NewFeatureName ];
        end
    end
    ArrayTempTable = array2table( ArrayTempMatrix );
    ArrayTempTable.Properties.VariableNames = ChannelNames;
    RowTempTable = array2table( RowTempMatrix );
    RowTempTable.Properties.VariableNames = RowColumnNames;
    FFTTable.Properties.VariableNames = ChannelNames;

end

function [ OversampleMatrix, ClassNames ] = getOversampledData( ...
            DataMatrix, QuantityPerClass )
    if isa( DataMatrix, 'table' )
        ClassNames = string( DataMatrix{:,size(DataMatrix,2)} );
    else
        ClassNames = string( DataMatrix(:,size(DataMatrix,2)) );
    end
    t=tabulate(ClassNames);
    if QuantityPerClass > max( [t{:,2}] )
        MaxSmplsForAClass = QuantityPerClass;
        ClassWithHighestSampleCount = '';
    else
        [MaxSmplsForAClass,iMaxSmplsForAClass]=max( [t{:,2}] );
        ClassWithHighestSampleCount = t{iMaxSmplsForAClass,1};
    end
    UniqueClassNames = unique( ClassNames );
    OversampleMatrix = DataMatrix;
    for c=1:size(UniqueClassNames)
        ClassName = UniqueClassNames(c);
        if ClassName ~= ClassWithHighestSampleCount
            ClassIndices = ClassNames == ClassName;
            ClassData = DataMatrix(ClassIndices,:);
            RepeatedClassData = datasample( ClassData, MaxSmplsForAClass-sum(ClassIndices) );
            RepeatedClassNames = strings( size(RepeatedClassData,1), 1 );
            RepeatedClassNames(:,1) = ClassName;

            OversampleMatrix = [ OversampleMatrix; RepeatedClassData ];   % append repeated data to matrix
            ClassNames = [ ClassNames; RepeatedClassNames ];
        end
    end
end

function plotChlAgainstChl( DataTable, XChlName, YChlName, Title )
    figure;
    XData = DataTable{ :, XChlName };
    YData = DataTable{ :, YChlName };
    gscatter( XData, YData, DataTable.Class )
    xlabel( XChlName );
    ylabel( YChlName );
    title( strcat( {Title}, {' '}, {XChlName}, {' vs '}, {YChlName} ) )
end

function plotFeatureAgainstFeature( FeaturesTable, XColName, YColName, Title )
    XData = FeaturesTable{ :,XColName };
    YData = FeaturesTable{ :,YColName };
    figure;
    gscatter( XData, YData, FeaturesTable.Class )
    xlabel( XColName, 'Interpreter', 'none' );
    ylabel( YColName, 'Interpreter', 'none' );
    title( Title, 'Interpreter', 'none' ) 
end

function NoisyCellArray = addGaussianNoise( CellArray, Amplitude )
    % ADD GAUSSIAN NOISE TO DATA
    NoisyCellArray = CellArray;
    for i=1:size(NoisyCellArray,1)
        SmplFeatData = NoisyCellArray{i,1};
        GaussNoise = random('norm', 0, Amplitude/4, size(SmplFeatData,1), size(SmplFeatData,2));
        SmplFeatData = SmplFeatData + GaussNoise;
        NoisyCellArray{i,1}=SmplFeatData;
    end
end

function plotFFT( FFTTable, ChlName, SmplFreq )
    figure;
    FreqDomPoints = 0:SmplFreq/2;
    ClassCol = size(FFTTable,2);
    FreqDomCol = size(FFTTable,2)+1;
    for i=1:(SmplFreq/2)+1:size(FFTTable,1)
        FFTTable{ i : i+(SmplFreq/2), FreqDomCol } = ...
            FreqDomPoints';
    end
    XData = FFTTable{:,FreqDomCol};
    YData = FFTTable{:,ChlName};
    Groupings = FFTTable{:,ClassCol};
    gscatter( XData, YData,Groupings )
    xlabel( 'Frequency(Hz)' )
    ylabel( 'Amplitude' )
    title( ['Raw Frequency-Domain ', ChlName ] )
end

function plotTIME( RawTable, ChlName, ObsPerFile, SmplFreq )    
    % DUE TO SIZE, WE JUST SAMPLE THE TIME-SERIES DATA AND PLOT THAT
    figure;
    cvp = cvpartition( size(RawTable,1),'Holdout', 10*ObsPerFile/size(RawTable,1) );
    idxTest = test( cvp );    % Test set indices
    PlottableTable = RawTable( idxTest, : );
    TimeDomPoints = 1/SmplFreq:1/SmplFreq:ObsPerFile/SmplFreq;
    TimeDomPointsArray = repmat( TimeDomPoints', size(PlottableTable,1)/ObsPerFile );
    XData = TimeDomPointsArray;
    YData = PlottableTable{:,ChlName};
    Groupings=PlottableTable{:,size(PlottableTable,2)};
    gscatter( XData, YData,Groupings )
    xlabel( 'Time Steps' )
    ylabel( 'Amplitude' )
    title( ['Raw Time-Domain ', ChlName ] )
end

    end % end methods sections
end % end EMG_CNN class