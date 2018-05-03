function FFTTable = getFFT( DataTable, ObsPerFile, LowFreq, HighFreq, UseFreqDomain, SmplFreq, BandStopFreq ) 
    %% Filtering Parameters
    %
    Fs = SmplFreq ;     % Read the Sampling Frequency  
    %
    Fu = HighFreq;   % Read the Upper Cut off Frequency of the LPF
    % 
    Nl = 5 ;     % Read the Order of the LPF
    %
    Fl = LowFreq ;    % Read the Lower Cut off Frequency of the HPF
    %
    Nh = 5 ;     % Read the Order of the HPF
    %
    Fn = BandStopFreq ; % Read the notch cut off frequency
    %
    Qf = 10 ;  % Read the Quality Factor
    %
    nf = 5 ;  % Read the order of the notch
    %
    %% Design of the LPF 
    [bl,al] = butter(Nl,2*Fu/Fs); %Impulse Response of LPF
    %% Design of the HPF
    [bh,ah] = butter(Nh,2*Fl/Fs,'high'); % Impulse Response cofficients of the High Pass Filter
    %% Design of the Notch Filter
    df=Fn/Qf;
    Fn1=2*(Fn-df/2)/Fs;
    Fn2=2*(Fn+df/2)/Fs;
    [bn,an] = butter(nf,[Fn1 Fn2],'stop'); % Impulse Response cofficients of the Notch Filter

    DataArray = table2array( DataTable );
    RotatedArray = rot90( DataArray );
    for i=1:size( DataTable, 2 )
        
        passingLow(i,:)=filter(bl,al,RotatedArray(i,:));   
        passingBand(i,:)=filter(bh,ah,passingLow(i,:));
        filterData(i,:)=filter(bn,an,passingBand(i,:));
        if UseFreqDomain == 1
            Y = fft( filterData(i,:), Fs );
            Y = Y( 1:Fs/2+1 );
            P2 = abs( Y );       
            fftData(i,:) = P2;
        else
            fftData = filterData;
        end
    end
    ReversedRotatedArray = rot90( fftData, 3 );
    FFTTable = array2table( ReversedRotatedArray );  
end


