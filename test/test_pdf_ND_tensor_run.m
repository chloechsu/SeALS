
%% Test Tensor Form PDF Evolution ND
clear all


%% Create operator in tensor form
% Initialization

dim = 4;
x = sym('x',[dim,1]); %do not change
%n = [101,111,121,131,101,101];

% Initial distribution
sigma02 = 0.55;
x0 = zeros(dim,1);
n = zeros(dim,1);
for i=1:dim
    n(i) = 101+10*i;
    bdim(i,:) = [-pi  pi];
    x0(i) = -1;%2+i/dim*10;
    diagSigma(i) = sigma02 + i/dim*0.1;
end
bdim(2,:) = [-10  10];

caseNum = 0;%'pendulum2D';

if strcmp('pendulum2D',caseNum) && dim==2
   fprintf ('Running case  "%s"  with %d dimensions\n', caseNum, dim)
   dim = 2;
   n(1) = 401;
   n(2) = 401;
   x0 = [0.2, 0.01];
   diagSigma = [0.03 0.001];
   thetadotmax = sqrt(2*(1-cos(x0(1)))) + x0(2);
   bdim = [-2*pi 2*pi;-thetadotmax*3 +3*thetadotmax];
else
    fprintf ('Running generic case with %d dimensions\n', caseNum, dim)
end

fprintf ('The grid size is %d in dimension %d \n', [n,(1:dim)']')
for i=1:dim
    dx(i) = (bdim(i,2)-bdim(i,1))/(n(i)-1);
    xvector{i} =  (bdim(i,1):dx(i):bdim(i,2))';
end


sigma02Matrix = diag(diagSigma); % [0.8 0.2; 0.2 sigma02];
for i=1:dim
   p0vector{i} =  normpdf(xvector{i},x0(i),sqrt(diagSigma(i))); %*0.5 + normpdf(xvector{i},2*x0(i),sqrt(diagSigma(i)))*0.5;
end

if dim == 2
    [xgrid,ygrid] = meshgrid(xvector{1},xvector{2});
    xyvector = [reshape(xgrid,n(1)*n(2),1),reshape(ygrid,n(1)*n(2),1)];
end    
    %p0 = reshape(mvnpdf(xyvector,x0,sigma02Matrix),n(2),n(1));
    %rankD = 10;
    %[p0compressed] = cp_als(tensor(p0),rankD);
%else
    p0compressed = ktensor(p0vector);
%end

% Create tensor structure
pk{1} = p0compressed;

%% Tensor parameters

for i=1:dim
   bcon{i} = {'d',0,0};
end
bcon{1} = {'p'};
bsca = []; %no manual scaling
region = [];
regval = 1;
regsca = [];
sca_ver = 1;

tol_err_op = 1e-6;
tol_err = 1e-9;
als_options = [];
als_variant = []; %{10,50};
debugging = 0;

run = 1;

fprintf(['Starting run ',num2str(run),' with main_run \n'])

for i=1:dim
    gridT{i} = xvector{i};
    nd(i) = n(i);
    dxd(i) = dx(i);
    acc(:,i) = [2,2]';
end
[D,D2,fd1,fd2] = makediffop(gridT,nd,dxd,acc,bcon,region);

% Simulation Parameters
dt = 0.001;
finalt = 1% 2*pi*0.5/;
t = 0:dt:finalt;
aspeed = zeros(dim,1);
qdiag = zeros(dim,1);
for i=1:dim
    qdiag(i) = 0.25; % 0.3 + i/dim*0.4;
    aspeed(i) = 0.5;% 4 - i/dim*3;
end
%qdiag = [0.01 0.001];
q =  diag( qdiag ); %[0.3,0.6]); %0.25;
% q(2,2) = 0.2; 
% q(1,1) = 0.02;
%aspeed = [2;-2]; %[0,3]';

xkalman = zeros(dim,length(t));
covkalman = zeros(dim,dim,length(t));
expec = zeros(dim,length(t));
cov = zeros(dim,dim,length(t));

% Step up variables
cov(:,:,1) = sigma02Matrix;
expec(:,1) = x0;

% Kalman variables .. Equation xdot = a*x + noise
xkalman(:,1) = x0;
covKalman(:,:,1) = sigma02Matrix;

alinear = 1:dim;

%% Create Cell Terms
%fFPE = sym(aspeed); % constant speed

kpen = (2*pi/3)^2;
%fFPE = [x(2);-kpen*sin(x(1))];

% fFPE = [-x(2);-kpen*x(1)]; % Linear Pendulum
fFPE = alinear';


fFPE_function = @(x1,x2,x3,x4,x5) fFPE;  %matlabFunction(fFPE);
fPFEdiff = jacobian(fFPE,x);

fTens  = fcell2ftens( fsym2fcell(sym(fFPE) ,x), gridT);
f_pTensqTens = fcell2ftens( fsym2fcell(diag(fPFEdiff) ,x), gridT);
dtTens = fcell2ftens( fsym2fcell(sym(dt)     ,x), gridT);
qTens  = fcell2ftens( fsym2fcell(sym(q)      ,x), gridT);
dtTen = DiagKTensor(dtTens{1}); 

% Create Operator
op = create_FP_op ( fTens, f_pTensqTens, qTens, D, D2, dtTen, gridT, tol_err_op);

% Create weights for integration
for i=1:dim
    for j = 1:dim
        if i == j
            we{i,j} = xvector{j};
        else
            we{i,j} = ones(n(j),1);
        end         
    end
end
for i=1:dim
    weones{i} = ones(n(i),1);
end
weCov = cell(dim,dim,dim);
for i=1:dim
    for j = 1:dim
        weCov(i,j,:) = weones;
        if i == j
            weCov{i,j,i} = xvector{j}.*xvector{j};
        else
            weCov{i,j,i} = xvector{i};
            weCov{i,j,j} = xvector{j};
        end         
    end
end


%% Iterate over 


time1 = tic;
for k = 2:length(t)
    
    % 
    pk{k} = SRMultV( op, pk{k-1});
    if length(pk{k}.lambda) > 1
        [pk{k},~] = tenid(pk{k},tol_err_op,1,9,'frob',[],fnorm(pk{k}),0);
        pk{k} = fixsigns(arrange(pk{k}));
        [pk{k}, err_op, iter_op, enrich_op, t_step_op, cond_op, noreduce] = als2(pk{k},tol_err_op);
    end

    
    % Get Mean and Covariance values
    for i=1:dim
        expec(i,k)  = intTens(pk{k}, [], gridT, we(i,:));
    end
    for i=1:dim
        for j = 1:dim
            cov(i,j,k) = intTens(pk{k}, [], gridT, weCov(i,j,:)) - expec(i,k)*expec(j,k);
        end
    end

    % Integrate the GT
    xkalman(:,k)  = deval(ode45( @(t,x) tempCall(fFPE_function,t,x),[t(k-1) t(k)], xkalman(:,k-1)'),t(k));
    %covKalman(:,:,k) = covKalman(:,:,k-1) + q*dt;
    %[xkalman(:,k),covKalman(:,:,k)]=ukf( @(xx) [xx(2);-kpen.*sin(xx(1))-0.0*xx(2)],xkalman(:,k-1),covKalman(:,:,k-1),0,0,q,0);
    
    %% Measure
    zmes = xkalman(:,k) + randn(dim,1).*sqrt(diagSigma)';
    %diagSigma = sigma02 + 0.2*(0:1/(dim-1):1);
    %Rmes = diag(diagSigma); % [0.8 0.2; 0.2 sigma02];
    for i=1:dim
       pz{i} =  normpdf(xvector{i},zmes(i),sqrt(diagSigma(i))); %*0.5 + normpdf(xvector{i},2*x0(i),sqrt(diagSigma(i)))*0.5;
    end
    zkcompressed = ktensor(pz);
    
    if (k<-1 )
        % Direct PDF Bayesian Measurement
        pk{k} = HadTensProd(pk{k},zkcompressed);
        pk{k} = pk{k} *(1/  intTens(pk{k}, [], gridT, weones));
    end
    
    % Kalman Measurement
%     HK = eye(dim);
%     KalmanG = covKalman(:,:,1)*HK'*inv(HK*covKalman(:,:,1)*HK'+Rmes);
%     xposKalman = xkalman(:,1) + KalmanG*(zmes - HK*xkalman(:,1));
%     covKalmanPos = (eye(dim)-KalmanG*HK)*covKalman(:,:,1);
end
toc(time1)
%% Check Results


% Check Kalman 
figure
plot(t,xkalman,t,expec,'.')
xlabel('time')
zlabel('position')
%legString = [];
for i=1:dim
    legString{i}= strcat('Kalman ' , num2str(i)); 
end
for i=1:dim
    legString{dim+i}=strcat('FPE ' , num2str(i)); 
end
legend(legString)
% for k=1:length(t)
%    trCov(k) = det(cov(:,:,k)); 
%    trCovKalman(k) = det(covKalman(:,:,k)); 
% end
% figure
% plot(t,trCov,t,trCovKalman,'.')
% xlabel('time')
% ylabel('cov det')
% legend('FPE','Kalman')

figure
plot(t,sqrt(sum((xkalman-expec).^2)))
xlabel('time')
ylabel('mean error')
title('Square Error')

%Compare 2D map kalman and Tensor-FKE
if dim==2
    figure
    plot2d( xvector, reshape(mvnpdf(xyvector, xkalman(:,k)',covKalman(:,:,end)),n(2),n(1))'-double(pk{end}) )
    title('Difference with kalman')
end




%% animated figure
hf = figure
save_to_file = 1;
if (save_to_file  )
    FPS = 25;  
    pause(1)
    str_title = ['Probability Density Function Evolution. f(x) = sin(x)'];
    writerObj = VideoWriter('pdf_gaussian_.avi');
    writerObj.FrameRate = FPS;
    myVideo.Quality = 100;
    set(hf,'Visible','on');
    open(writerObj);
    set(gcf,'Renderer','OpenGL'); %to save to file
    pause(5)
end
if dim==2
    hf = figure
    hold on
    ht_pdf = pcolor(xvector{1},xvector{2},double(pk{1})');    
    ht_kf = scatter(xkalman(1,1) ,xkalman(2,1) );
    h = colorbar;
    %set(h, 'ylim', [0 0.25])
    %caxis([0 15])
    set(ht_pdf, 'EdgeColor', 'none');
    xlabel('x')
    ylabel('y')
    grid on
    axis ([bdim(1,:),bdim(2,:)])
    grid on

    
    for k = 2:15:length(t)
         set ( ht_pdf, 'CData', double(pk{k})' );
         set ( ht_kf, 'XData', xkalman(1,k),'YData', xkalman(2,k) );
         drawnow
         pause(1.0/1000);
         if (save_to_file )
             M = getframe(gcf); %hardcopy(hf, '-dzbuffer', '-r0');
             writeVideo(writerObj, M);
         end
    end

else
    handleSlices = plot2DslicesAroundPoint( pk{1}, x0, gridT);
    for k = 2:30:length(t)
        plot2DslicesAroundPoint( pk{k}, expec(:,k), gridT, handleSlices)
        if (save_to_file )
            M = getframe(gcf); %hardcopy(hf, '-dzbuffer', '-r0');
            writeVideo(writerObj, M);
        end        
    end
end

if (save_to_file  )
    close(writerObj);
end

 