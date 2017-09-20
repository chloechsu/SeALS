function [ handleOutput ] = plot2DslicesMarginalized(Ftensor, gridT, handleInput )
    % Plots a visualization of the Tensor. Integrate over all dimensions
    % but two.
    %
    % Inputs:
    % F - ktensor (n dims)
    % point - (nx1 vector) 
    % grid - cell of grid points of {n vectors}
    % handleInput - handles to generate animation
    
    % Outputs:
    % Slice Representation
    %
    % Usage: 
    %  - Static Plot: call the function without the handleInput
    %  - Animation: load the plot first using a static plot and then call
    %  the function in a loop, example code:
    %      
    %      figure
    %      handleSlices = plot2DslicesAroundPoint( Ftensor{1}, point(1,:), gridT);
    %      for k = 2:30:length(t)
    %          plot2DslicesAroundPoint( Ftensor{k}, point(:,k), gridT, handleSlices)    
    %      end
    %
    %
    
    dim = ndims(Ftensor);
    if isempty(handleInput)
        handleOutput = {};
        
        for i=1:dim 
            handleOutput{i,i} = subplot(dim,dim,dim*(i-1)+i);
            grid on
            hold on
            xlabel(['x_',num2str(i)])
            title('     Basis Function Marginalized')
            plot( gridT{i}, sum( repmat(Ftensor.lambda',size(Ftensor.U{i},1),1).*Ftensor.U{i},2));  
            for j=(i+1):dim
                subplot(dim,dim,dim*(i-1)+j)
                handleOutput{i,j} = plot2DsliceM(Ftensor,[i,j],gridT);
            end
        end    
    else
        for i=1:dim             
            handle_r = subplot(dim,dim,dim*(i-1)+i);
            cla(handle_r)
            %ylim([-1,1])
            hold on
            sizeU = size(Ftensor.U{i});
            plot( gridT{i}, sum( repmat(Ftensor.lambda',size(Ftensor.U{i},1),1).*Ftensor.U{i},2));  
            for j=(i+1):dim
                plot2DsliceM(Ftensor,[i,j],gridT,handleInput{i,j});
            end
        end 
        drawnow limitrate
        pause(1.0/1000);
        
    end
        
        


end