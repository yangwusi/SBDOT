function [] = Train( obj )
% TRAIN 
%   Learn the statistical relationship of the data
%
% Syntax examples :
%   []=obj.train();

% Superclass method
obj.Train@Metamodel();

if obj.prob.display, fprintf('\nTraining starting...');end

if isempty(obj.hyp_corr)
    
    % Default bounds
    if isempty( obj.lb_hyp_corr ) || isempty( obj.ub_hyp_corr )
        
        if xor( isempty(obj.lb_hyp_corr), isempty(obj.ub_hyp_corr) )
            warning('SBDOT:Kriging:HypBounds_miss','Both bounds lb_hyp_corr and ub_hyp_corr have to be defined ! Default values are applied')
        end
        
        % Bounds based on inter-distances of training points
        [ hyp_corr0_temp, lb_hyperp_temp, ub_hyperp_temp ] = Theta_bound_normal( obj.x_train );
        obj.lb_hyp_corr = log10( ( 1./(sqrt(2)*ub_hyperp_temp) ).^2 );
        obj.ub_hyp_corr = log10( ( 1./(sqrt(2)*lb_hyperp_temp) ).^2 );
        
        % Set initial value of hyp_corr for optimization
        if isempty(obj.hyp_corr0)
            
            obj.hyp_corr0 = log10( ( 1./(sqrt(2)*hyp_corr0_temp) ).^2 );
        
        else
            
            assert( size(obj.hyp_corr0,2) == obj.prob.m_x ,...
            'SBDOT:Kriging:Hyp0_size',...
            'hyp_corr0 must be of size 1-by-m_x');
            
            obj.hyp_corr0 = log10( obj.hyp_corr0 );
            
        end
        
    else
        
        assert( size(obj.lb_hyp_corr,2) == obj.prob.m_x ,...
            'SBDOT:Kriging:HypBounds_size',...
            'lb_hyp_corr must be of size 1-by-m_x');
        
        assert( size(obj.ub_hyp_corr,2) == obj.prob.m_x ,...
            'SBDOT:Kriging:HypBounds_size',...
            'ub_hyp_corr must be of size 1-by-m_x');
        
        assert( all( obj.lb_hyp_corr < obj.ub_hyp_corr , 2),...
            'SBDOT:Kriging:HypBounds',...
            'lb_hyp_corr must be lower than ub_hyp_corr');
        
        % User defined
        obj.ub_hyp_corr = log10( obj.ub_hyp_corr );
        obj.lb_hyp_corr = log10( obj.lb_hyp_corr );
        if isempty(obj.hyp_corr0 ) % hyp_corr0 user defined or not
            obj.hyp_corr0 = ( obj.lb_hyp_corr + obj.ub_hyp_corr ) ./ 2;
        else
            assert( size(obj.hyp_corr0,2) == obj.prob.m_x ,...
            'SBDOT:Kriging:Hyp0_size',...
            'hyp_corr0 must be of size 1-by-m_x');
            
            obj.hyp_corr0 = log10( obj.hyp_corr0 );
        end
        
    end
    
else % no optimization of hyp_corr
    
    assert( size(obj.hyp_corr,2) == obj.prob.m_x ,...
            'SBDOT:Kriging:Hyp_val_size',...
            'hyp_corr0 must be of size 1-by-m_x');
        
    obj.hyp_corr0 = log10(obj.hyp_corr);
    obj.lb_hyp_corr = log10(obj.hyp_corr);
    obj.ub_hyp_corr = log10(obj.hyp_corr);
        
end

% Set optimization options
opts = ooDACE.Kriging.getDefaultOptions();
opts.regressionMaxLevelInteractions = obj.prob.m_x;
opts.hpLikelihood = obj.estim_hyp;
% Options depending on estimation methods
if isequal( obj.estim_hyp, @pseudoLikelihood )
    optimopt.GradObj = 'off';
    optimopt.MaxIterations = 2000;
    optimopt.MaxFunctionEvaluations = 2000;
    optimopt.StepTolerance = 1e-10;
    opts.hpOptimizer = ooDACE.MatlabOptimizer( 1,1, optimopt );
end
% If asked, global optimization instead of local
if obj.go_opt
    optimopt.TolX = 1e-4;
    optimopt.Restarts = 0;
    optimopt.IncPopSize = 1;
    optimopt.TolFun = 1e-4;
    optimopt.DispModulo = 0;
    opts.hpOptimizer = ooDACE.CmaesOptimizer( 1,1, optimopt );
end


% Regression (if asked)
if obj.reg
    
    if obj.prob.display, fprintf('\nRegression activated\n');end
    
    if isempty(obj.hyp_reg)            
        
        if isempty( obj.lb_hyp_reg ) || isempty( obj.ub_hyp_reg )
            
            if xor( isempty(obj.lb_hyp_reg), isempty(obj.ub_hyp_reg) )
                warning('SBDOT:Kriging:RegBounds_miss','Both bounds lb_reg and ub_reg have to be defined ! Default values are applied')
            end
            obj.lb_hyp_reg = 1e-8;
            obj.ub_hyp_reg = max( var(obj.f_train), 1e-7 );
            
        else % user defined
            
            assert( all( obj.lb_hyp_reg < obj.ub_hyp_reg , 2),...
                'SBDOT:Kriging:RegBounds',...
                'lb_hyp_reg must be lower than ub_hyp_reg');
            
        end
        
        opts.reinterpolation = true;
        
        opts.lambda0 = log10( (obj.lb_hyp_reg + obj.ub_hyp_reg) / 2 );
        
        opts.lambdaBounds = log10([obj.lb_hyp_reg ; obj.ub_hyp_reg]);
        
    else
        % user defined
        opts.lambda0 = log10( obj.hyp_reg );
        opts.lambdaBounds = log10( [obj.hyp_reg ; obj.hyp_reg] );
        
    end
end

opts.hpBounds = [obj.lb_hyp_corr ; obj.ub_hyp_corr];

% Build ooDace Kriging
obj.k_oodace = ooDACE.Kriging( opts, obj.hyp_corr0, obj.regpoly, obj.corr);
obj.k_oodace = obj.k_oodace.fit(obj.x_train,obj.f_train);

if obj.prob.display, corr_name=func2str(obj.corr); fprintf(['\nKriging with ',corr_name(22:end),' correlation function is created.\n\n']);end

% Extract parameters with input space scaling
obj.hyp_corr = 10.^obj.k_oodace.getHyperparameters;

hyp_reg_temp = obj.k_oodace.getSigma;
obj.hyp_reg = hyp_reg_temp(1,1);

obj.hyp_corr_bounds = 10.^[min(obj.lb_hyp_corr) , max(obj.ub_hyp_corr)];
obj.hyp_reg_bounds = [obj.lb_hyp_reg , obj.ub_hyp_reg];

end





% ==========================================================================
%
%    This file is part of SBDOT.
%
%    SBDOT is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    SBDOT is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%????????along with SBDOT.????If not, see <http://www.gnu.org/licenses/>.
%
%    Use of SBDOT is free for personal, non-profit, pure academic research
%    and educational purposes. Restrictions apply on commercial or funded
%    research use. Please read the IMPORTANT_LICENCE_NOTICE file.
%
% ==========================================================================


