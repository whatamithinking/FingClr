% SourceDataDir = 'C:\Users\conno\OneDrive\Desktop\FingClr\DATA\CSV';
% DestDataDir = 'C:\Users\conno\OneDrive\Desktop\FingClr\DATA\TRIMMED';

% GET LIST OF FILE PATHS
% DataFileNames = dir( fullfile( SourceDataDir, '*.csv' ) );

% % GET MIN ROW COUNT
% MinActionSize = 1000000;
% for i = 1:length( DataFileNames )
%     SourceFilePath = fullfile( SourceDataDir, DataFileNames(i).name )
%     ActionData = xlsread( SourceFilePath );
%     ActionRowCount = size( ActionData, 1 );
%     if ActionRowCount < MinActionSize
%         MinActionSize = ActionRowCount;
%     end
% end

MinActionSize = 2640;
% % GET THE MINIMUM ROW COUNT, SO THAT ALL FILES CAN BE CLIPPED TO SIZE
% for i = 1:length( DataFileNames )
%     
%     % READ CSV DATA FROM FILE
%     SourceFilePath = fullfile( SourceDataDir, DataFileNames(i).name );
%     ActionDataSet = dataset( 'XLSFile', SourceFilePath );
%     
%     % TRIM CSV DATA ACCORDING TO SHORTEST ACTION DURATION
%     ActionDataSet = ActionDataSet( 1:MinActionSize, : );
%     
%     % SAVE CHANGES TO DEST DIR
%     [ FilePath, FileName, Extension ] = fileparts( SourceFilePath );
%     DestFilePath = fullfile( DestDataDir, strcat( FileName, '.xlsx' ) );
%     export( ActionDataSet, 'XLSfile', DestFilePath);
%     
% end

% SPLIT REST FILE INTO SEPARATE FILES
SourceRestFilePath = "C:\Users\conno\OneDrive\Desktop\CODE_VERSION_4\FingClr_Rest_1.csv";
DestRestFilePath = "C:/Users/conno/OneDrive/Desktop/CODE_VERSION_4/Rest/FingClr_Rest_%d.xlsx";
% ActionDataSet = dataset( 'XLSFile', SourceRestFilePath );
iFileName = 1;
length( ActionDataSet )
for i = 1:MinActionSize:length( ActionDataSet )
    ActionDataChunk = ActionDataSet( i:i+MinActionSize-1,: );
    DestFilePath = sprintf( DestRestFilePath, iFileName )
    export( ActionDataChunk, 'XLSfile', DestFilePath);
    iFileName = iFileName + 1
end







