% New surrogates code

function [surr,params]=surrcalc(sig, N, method, pp, fs, varargin)
z=clock;
% surr - surrogate signal(s)
% sig - input signal
% N - number of surrogates
% method - string input of required surrogate type
% pp - preprocessing on (1) or off (0) (match beginning and end and first
% derivatives

% Input sig should be the original time series, or phase for CPP
% For surrogates requiring embedding, the delay tau and dimension D are
% calculated automatically using false nearest neighbours and first 0
% autocorrelation, respectively.

% varargin options
% if method = 'FT', random phases can be input and output, to preserve for
% multivariate surrogates for example
% if method = 'PPS' or 'TS', embedding dimension can be entered beforehand instead of
% being estimated, if it is to be kept the same for all surrogates
% if method = 'CSS', minimum peak height and minimum peak distance can be
% entered to ensure correct peak detection for separation of cycles.

% Available surrogates:
% RP - Random permutation
% FT - Fourier transform
% AAFT - Amplitude adjusted Fourier transform
% IAAFT1 - Iterative amplitude adjusted Fourier transform with exact
% distribution
% IAAFT2 - Iterative amplitude adjusted Fourier transform with exact
% spectrum
% WIAAFT - % MODWT surrogates (WIAAFT)

% Implementing surrogates from Keylock, C. J. (2006) "Constrained surrogate time series with preservation of the mean and variance structure" PRE,
% 73, 036707, using wmtsa package developed in Percival, D. B. and A. T. Walden (2000) "Wavelet Methods for Time Series Analysis":
% http://www.atmos.washington.edu/~wmtsa/

% tshift - Time shifted
% CPP - cyclic phase permutation

origsig=sig;
params.origsig=origsig;
params.method=method;
params.numsurr=N;
params.fs=fs;


%%%%%%% Preprocessing %%%%%%%
if pp==1
    [sig,time,ks,ke]=preprocessing(sig,fs);
else
    time=linspace(0, length(sig)/fs,length(sig));
end
L=length(sig);
L2=ceil(L/2);
if pp==1
    params.preprocessing='on';
    params.cutsig=sig;
    params.sigstart=ks;
    params.sigend=ke;
else
    params.preprocessing='off';
end
params.time=time;

%%%%%%% Random permutation (RP) surrogates %%%%%%%
if strcmp(method,'RP')
    for k=1:N
        surr(k,:)=sig(randperm(L));
    end
    
    
    %%%%%%% Fourier transform (FT) surrogate %%%%%%%
elseif strcmp(method,'FT')
    
    a=0; b=2*pi;
    if nargin>5
        eta=varargin{1};
    else
        eta=(b-a).*rand(N,L2-1)+a; % Random phases
    end
    ftsig=fft(sig); % Fourier transform of signal
    ftrp=zeros(N,length(ftsig));
    
    ftrp(:,1)=ftsig(1);
    F=ftsig(2:L2);
    F=F(ones(1,N),:);
    ftrp(:,2:L2)=F.*(exp(1i*eta));
    ftrp(:,2+L-L2:L)=conj(fliplr(ftrp(:,2:L2)));
    
    surr=ifft(ftrp,[],2);
    
    params.rphases=eta;
    
    
    
    %%%%%%% Amplitude adjusted Fourier transform surrogate %%%%%%%
elseif strcmp(method,'AAFT')
    
    a=0; b=2*pi;
    eta=(b-a).*rand(N,L2-1)+a; % Random phases
    [val,ind]=sort(sig);
    rankind(ind)=1:L;    % Rank the locations
    
    gn=sort(randn(N,length(sig)),2); % Create Gaussian noise signal and sort
    for j=1:N
        gn(j,:)=gn(j,rankind); % Reorder noise signal to match ranks in original signal
    end
    
    ftgn=fft(gn,[],2);
    F=ftgn(:,2:L2);
    
    surr=zeros(N,length(sig));
    surr(:,1)=gn(:,1);
    surr(:,2:L2)=F.*exp(1i*eta);
    surr(:,2+L-L2:L)=conj(fliplr(surr(:,2:L2)));
    surr=(ifft(surr,[],2));
    
    [~,ind2]=sort(surr,2); % Sort surrogate
    rrank=zeros(1,L);
    for k=1:N
        rrank(ind2(k,:))=1:L;
        surr(k,:)=val(rrank);
    end
    
    
    %%%%%%% Iterated amplitude adjusted Fourier transform (IAAFT-1) with exact distribution %%%%%%%
elseif strcmp(method,'IAAFT1')
    maxit=1000;
    [val,ind]=sort(sig);  % Sorted list of values
    rankind(ind)=1:L; % Rank the values
    
    ftsig=fft(sig);
    F=ftsig(ones(1,N),:);
    surr=zeros(N,L);
    
    for j=1:N
        surr(j,:)=sig(randperm(L)); % Random shuffle of the data
    end
    
    it=1;
    irank=rankind;
    irank=irank(ones(1,N),:);
    irank2=zeros(1,L);
    oldrank=zeros(N,L);
    iind=zeros(N,L);
    iterf=zeros(N,L);
    
    while max(max(abs(oldrank-irank),[],2))~=0 && it<maxit
        go=max(abs(oldrank-irank),[],2);
        [~,inc]=find(go'~=0);
        
        oldrank=irank;
        iterf(inc,:)=real(ifft(abs(F(inc,:)).*exp(1i*angle(fft(surr(inc,:),[],2))),[],2));
        
        [~,iind(inc,:)]=sort(iterf(inc,:),2);
        for k=inc
            irank2(iind(k,:))=1:L;
            irank(k,:)=irank2;
            surr(k,:)=val(irank2);
        end
        
        it=it+1;
    end
    
    
    %%%%%%% Iterated amplitude adjusted Fourier transform (IAAFT-2) with exact spectrum %%%%%%%
elseif strcmp(method,'IAAFT2')
    maxit=1000;
    [val,ind]=sort(sig);  % Sorted list of values
    rankind(ind)=1:L; % Rank the values
    
    ftsig=fft(sig);
    F=ftsig(ones(1,N),:);
    surr=zeros(N,L);
    
    for j=1:N
        surr(j,:)=sig(randperm(L)); % Random shuffle of the data
    end
    
    it=1;
    irank=rankind;
    irank=irank(ones(1,N),:);
    irank2=zeros(1,L);
    oldrank=zeros(N,L);
    iind=zeros(N,L);
    iterf=zeros(N,L);
    
    while max(max(abs(oldrank-irank),[],2))~=0 && it<maxit
        go=max(abs(oldrank-irank),[],2);
        [~,inc]=find(go'~=0);
        
        oldrank=irank;
        iterf(inc,:)=real(ifft(abs(F(inc,:)).*exp(1i*angle(fft(surr(inc,:),[],2))),[],2));
        
        [~,iind(inc,:)]=sort(iterf(inc,:),2);
        for k=inc
            irank2(iind(k,:))=1:L;
            irank(k,:)=irank2;
            surr(k,:)=val(irank2);
        end
        
        it=it+1;
        
    end
    surr=iterf;
    
    %%%%%%% Time-shifted surrogates %%%%%%%
elseif strcmp(method,'tshift')
    %nums=randperm(L);
    for sn=1:N
        startp=randi(L-1,1);%nums(sn);%
        surr(sn,:)=horzcat(sig(1+startp:L),sig(1:startp));
    end
    
    %%%%%%% cycle phase permutation surrogates
elseif strcmp(method,'CPP')
    
    signal=mod(sig,2*pi);
    
    dcpoints=find(signal(2:end)-signal(1:end-1)<-pi);
    NC=length(dcpoints)-1;
    if NC>0
        cycles=cell(NC,1);
        for k=1:NC
            cycles{k}=signal(dcpoints(k)+1:dcpoints(k+1));
        end
        stcycle=signal(1:dcpoints(1));
        endcycle=signal(dcpoints(k+1)+1:end);
        
        for sn=1:N
            disp(size(stcycle));
            disp(NC);
            disp(size(cycles));
            disp(size(endcycle));
            
            surr(sn,:)=unwrap(horzcat(stcycle,cycles{randperm(NC)},endcycle));
        end
        
    else
        for sn=1:N
            surr(sn,:)=unwrap(signal);
        end
    end
    
    %%%%%%% Wavelet iterated amplitude adjusted Fourier transform surrogates
elseif strcmp(method,'WIAAFT')
        
    for k=1:N
        w=modwt(sig);
        N2=size(w,1);
        L=length(sig);
        matching=true;
        
        for j=1:N2
            tmp=surrcalc(sig, 1, 'IAAFT2', 0, fs);
            if matching
                surrLev(j,:)=matchRotation(w(j,:),tmp);
            else
                surrLev(j,:)=tmp;
            end
            
        end
        
        surrg=imodwt(surrLev);
        
        maxit = 200; % maximum number of iterations
        [sorted, sortInd] = sort(sig);
        itrank(sortInd) = linspace(1, L, L);
        ftsig = fft(sig);
        surrtmp = surrg;
        iter = 1;
        oldrank = zeros(1, L);
        
        while (max(abs(oldrank - itrank)) ~= 0 && iter < maxit) % equal spectrum, similar amplitude distribution
            oldrank = itrank;
            % replace Fourier amplitudes (real() since makes mistakes of order \epsilon)
            itFt = real(ifft(abs(ftsig).* exp(1i * angle(fft(surrtmp)))));
            [~, itind] = sort(itFt); % find the ordering of the new signal
            itrank(itind)= linspace(1, L, L);
            surrtmp = sorted(itrank);
            iter = iter + 1;
        end
        surr(k,:) = itFt;
    end
    
    %     nlevels='conservative';      % Number of levels of decomposition
    %     boundary='circular';         % Boundary conditions
    %     wtf='la16';                   % Wavelet transform filter
    %
    %     % Calculate MODWT
    %     [WJt, VJt, att] = modwt(sig, wtf, nlevels, boundary);
    %
    %     for k=1:N
    %
    %     % Apply IAAFT to each level of coefficients
    %     SWJt=zeros(L,att.J0);
    %     shiftSWJt=zeros(L,att.J0);
    %
    %         for j=1:att.J0 % to number of levels
    %             SWJt(:,j)=SURROGATES(WJt(:,j)',1,'IAAFT2',0,fs); % IAAFT of each level
    %             shiftSWJt(:,j)=matchsigs(WJt(:,j),SWJt(:,j));      % Match each surrogate or its mirror image as closely as possible to original data
    %
    %         end
    %
    %     % Calculate IMODWT
    %     surrtemp = imodwt(shiftSWJt, VJt, att); % Inverse MODWT for surrogates
    %     surrtemp=surrtemp';
    %
    %     % Use rank ordering method from standard IAAFT algorithm to recover the
    %     % values of the original time series
    %
    %     maxit=1000; % Maximum number of iterations
    %     it=1;
    %     [val,ind]=sort(sig);
    %     ranks(ind)=1:L;
    %
    %     irank=ranks;
    %     oldrank=zeros(L,1);
    %     iterf=zeros(L,1);
    %
    %         while max(max(abs(oldrank-irank')))~=0 && it<maxit
    %
    %             oldrank=irank;
    %             iterf=real(ifft(abs(fft(sig)).*exp(1i*angle(fft(surrtemp)))));
    %
    %             [~,iind]=sort(iterf);
    %             irank(iind)=1:L; irank=irank';
    %             surrtemp=val(irank');
    %
    %             it=it+1;
    %
    %         end
    %         surr(k,:)=iterf; % IAAFT2, perfect spectrum
    %     end
    %     params.MODWTlevels=att.J0;
    %     params.waveletfilter=wtf;
    
    
else
    
    
    
end


%%%%%%% Saving and plotting %%%%%%%

params.runtime=etime(clock,z);
params.type=method;
params.numsurr=N;
if pp==1
    params.preprocessing='on';
    params.cutsig=sig;
    params.sigstart=ks;
    params.sigend=ke;
else
    params.preprocessing='off';
end
params.time=time;
params.fs=fs;

end




function [cutsig,t2,kstart,kend]=preprocessing(sig,fs)
sig=sig-mean(sig);
t=linspace(0,length(sig)/fs,length(sig));
L=length(sig);
p=10; % Find pair of points which minimizes mismatch between p consecutive
%points and the beginning and the end of the signal

K1=round(L/100); % Proportion of signal to consider at the beginning
k1=sig(1:K1);
K2=round(L/10);  % Proportion of signal to consider at the end
k2=sig(end-K2:end);

% Truncate to match start and end points and first derivatives
if length(k1)<=p
    p=length(k1)-1;
else
end
d=zeros(length(k1)-p,length(k2)-p);

for j=1:length(k1)-p
    for k=1:length(k2)-p
        d(j,k)=sum(abs(k1(j:j+p)-k2(k:k+p)));
    end
end

[v,I]=min(abs(d),[],2);
[~,I2]=min(v); % Minimum mismatch

kstart=I2;
kend=I(I2)+length(sig(1:end-K2));
cutsig=sig(kstart:kend); % New truncated time series
t2=t(kstart:kend); % Corresponding time

end
