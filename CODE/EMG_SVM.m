classdef EMG_SVM
methods( Static )
function getExpModel( FeaturesTable, RunCount, MdlSaveDir, TestRatio, QuantityPerClass )

    TrainExp = [];
    TrainPred = [];
    TestExp = [];
    TestPred = [];
    TrainingClassNames = {};
    TestingClassNames = {};
    
    ExpMdlProgressBar = waitbar( 0, 'Calculating Expected Model...' );

    %% OVERSAMPLE TO GET EQUAL NUMBER OF POINTS FOR EACH CLASS
    [ OversampledTable, OM_ClassNames ] = EMG_CNN.getOversampledData( ...
        FeaturesTable, QuantityPerClass );
    [ Indices, CCellArr, ClassNamesArr ] = grp2idx( string( OM_ClassNames ) );
    OversampledTable.Class=Indices;
    
    for run=1:RunCount
        
        %% GET TRAINING / TESTING / VALIDATION DATA
        [ TrainingMatrix, TestingMatrix, RunTrainingClassNames, RunTestingClassNames  ] = ...
            EMG_CNN.getSampleData( OversampledTable, TestRatio, OM_ClassNames );
        TrainingClassNames = [ TrainingClassNames; RunTrainingClassNames ];
        TestingClassNames = [ TestingClassNames; RunTestingClassNames ];
        
        %% BUILD / TRAIN MODEL with train/validation data
        [ Mdl, TrainAccuracy ] = SVM_CLASSIFIER( TrainingMatrix );
      
        %% GET TRAIN RESULTS
        TrainPredictions = Mdl.predictFcn( TrainingMatrix(:,1:size(TrainingMatrix,2)-1) ); 
        TrainPred = [ TrainPred; TrainPredictions ];
        TrainExp = [ TrainExp; TrainingMatrix{:,size(TrainingMatrix,2)} ];

        %% GET TEST RESULTS
        TestPredictions = Mdl.predictFcn( TestingMatrix(:,1:size(TestingMatrix,2)-1) );
        TestPred = [ TestPred; TestPredictions ];
        TestExp = [ TestExp; TestingMatrix{:,size(TestingMatrix,2)} ];

        %% SAVE MODEL IF GOOD ACCURACY
        ConfMatrix = confusionmat( TestingMatrix{:,size(TestingMatrix,2)}, TestPredictions );
        ConfMatrixAccuracy = ConfMatrix ./ sum( ConfMatrix' )';
        ClassCount = size( unique(TestingMatrix(:,size(TestingMatrix,2))),1 );
        TestAccuracy = sum( diag( ConfMatrixAccuracy ) ) / ClassCount;
        if TestAccuracy >= 0.9  % save model if accuracy good enough
            FileName = strrep( strcat( MdlSaveDir,'\', ...
                            num2str( TestAccuracy ) ), '.','_' );
            save(FileName,'Mdl');
        end

        % UPDATE PROGRESS
        waitbar( run/RunCount, ExpMdlProgressBar )

    end
    close( ExpMdlProgressBar )

    % BUID CONFUSION MATRICES
    EMG_SVM.showResults( TrainPred, TrainExp, ClassNamesArr, 'Training ' )
    EMG_SVM.showResults( TestPred, TestExp, ClassNamesArr, 'Testing ' )

end

function showResults( Predicted, Expected, ClassNames, Title )
    figure;
    cm = confusionmat( Expected, Predicted );
    oPlot = plotConfMat( cm, ClassNames );
    OldTitle = get( oPlot, 'title' );
    title( strcat( { Title }, { OldTitle.String } ) );    
end
end % end methods
end % end emg_svm class
  
  
  
