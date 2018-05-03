
ActionNames = {'cyl','hook','lat','palm','spher','tip'};
ChannelNames = {'CH1','CH2'};
ObsPerFile = 3000;
ApproxFileCount = 180;
MaxChCount = 2;
Data = cellmat( ApproxFileCount, 1, ObsPerFile, MaxChCount );
ClassNames = strings(ApproxFileCount,1);

FilePaths = getAllFiles( ValidationDataDir );
iSample=0;
for f=1:size(FilePaths,1)
    load(FilePaths{f,1});
    for a=1:size(ActionNames,2)
        TempActionChlData = eval( strcat( ActionNames{1,a}, '_', lower( ChannelNames{1,1} ) ) );
        for s=1:size( TempActionChlData, 1 )
            TempMatrix=zeros(ObsPerFile,size(ChannelNames,2));
            for c=1:size(ChannelNames,2)
                ActionChlData = eval( strcat( ActionNames{1,a}, '_', lower( ChannelNames{1,c} ) ) );
                TempMatrix(:,c) = ActionChlData(s,:)';
            end
            iSample = iSample + 1;
            Data{iSample,1}=TempMatrix;
            ClassNames{iSample,1} = ActionNames{1,a};
        end
    end
end
FileCount = size( Data,1 );

function fileList = getAllFiles(dirName)
% src: https://stackoverflow.com/questions/2652630/how-to-get-all-files-under-a-specific-directory-in-matlab 
  dirData = dir(dirName);      %# Get the data for the current directory
  dirIndex = [dirData.isdir];  %# Find the index for directories
  fileList = {dirData(~dirIndex).name}';  %'# Get a list of the files
  if ~isempty(fileList)
    fileList = cellfun(@(x) fullfile(dirName,x),...  %# Prepend path to files
                       fileList,'UniformOutput',false);
  end
  subDirs = {dirData(dirIndex).name};  %# Get a list of the subdirectories
  validIndex = ~ismember(subDirs,{'.','..'});  %# Find index of subdirectories
                                               %#   that are not '.' or '..'
  for iDir = find(validIndex)                  %# Loop over valid subdirectories
    nextDir = fullfile(dirName,subDirs{iDir});    %# Get the subdirectory path
    fileList = [fileList; getAllFiles(nextDir)];  %# Recursively call getAllFiles
  end

end





