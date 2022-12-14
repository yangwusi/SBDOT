classdef Multi_obj_EI_MGDA < Adaptive_sampling
    % MULTI_OBJ_EI_MGDA 
    % Expected hypervolume improvement algorithm.
    % Multi-objective kriging based optimization method.
    % Unconstrained problems.
    %
    % obj = Multi_obj_EI_MGDA(prob, y_ind, g_ind, meta_type, N_eval, varargin)
    %
    % Mandatory inputs :
    %   - prob is a Problem/Problem_multifi object, created with the appropriate class constructor
    %   - y_ind is the index of the objective to optimize
    %   - g_ind is the index of the constraint(s) to take into account
    %   - meta_type is the type of metamodel to use (@Kriging or @Cokriging)
    %   - N_eval is the number of points to evaluate at each iterations
    %   (set to Inf for automatic good calibration)
    %
    % Optional inputs [default value]:
    %   - 'options_optim' is a structure for optimization of EI criterion
    %   see Set_options_optim for example of parameters structure
    %   * Optional inputs for Kriging apply
    %   * Optional inputs for Adaptive_sampling apply
    %
    properties
        
        % Mandatory inputs
        meta_type      % Type of metamodel
        N_eval         % Number of points to evaluate at each iteration.
        
        % Optional inputs
        options_optim  % Structure of user optimization options
        add_seq        % Boolean allowing sequential addition of points (for qualitative problems only)

        % Computed variables
        conv_crit      % Adpative sampling criterion value
        in_a_row       % Number of valid criterion value in a row
        y_pareto_temp  % Pareto front from problem values
        y_ref_temp     % Reference point for hypervolume computation
        n_Q_val        % Number of values of combination of qualitative variable

    end
    
    properties(Constant)
        Tol_inarow = 3;  % Successive tolerance success
    end
    
    methods
        
        function obj = Multi_obj_EI_MGDA(prob, y_ind, g_ind, meta_type, N_eval ,varargin)
           
            p = inputParser;
            p.KeepUnmatched = true;
            p.PartialMatching = false;
            p.addRequired('meta_type',@(x)isequal(x,@Kriging)||isequal(x,@Cokriging)||isequal(x,@Q_kriging));
            p.addRequired('N_eval',@(x)isnumeric(x));
            p.addOptional('options_optim',[],@(x)isstruct(x));
            p.addOptional('add_seq',false,@(x)islogical(x));
            p.parse(meta_type,N_eval,varargin{:})
            in = p.Results;
            unmatched = [fieldnames(p.Unmatched),struct2cell(p.Unmatched)];
            unmatched = unmatched';
            
            % Superclass constructor
            obj@Adaptive_sampling(prob,y_ind,g_ind,unmatched{:});
            
            % Store
            obj.options_optim = in.options_optim;
            obj.meta_type = in.meta_type;
            obj.N_eval = in.N_eval;
            
            
            % Checks
            assert( obj.m_y > 1 || ( isequal(meta_type,@Q_kriging) && obj.m_y == 1 && obj.m_g == 0), ...
                'SBDOT:Multi_obj_EI_MGDA:y_ind', ...
                horzcat('y_ind must be composed of at least 2 elements (multi-objective optimization)',...
                ' or prob must be a qualitative problem with 1 objective and no constraint (multi-modality optimization)'));
            
            % Set optimization options
            obj.Set_options_optim( obj.options_optim );
            
            % Train metamodel
            if isequal(meta_type,@Q_kriging)
                            
                obj.add_seq = in.add_seq;
            
                if obj.add_seq

                    assert(prob.m_x > 1,...
                        'SBDOT:Q_multi_obj_EI_MGDA:add_seq', ...
                        'When add_seq is set to true, prob.m_x shall be at least 2');

                end
                
                obj.meta_y = obj.meta_type(obj.prob, obj.y_ind, [], obj.unmatched_params{:});
                
            else
                
                for i=1:obj.m_y
                    metamodel_int_y(i,:) = ...
                        obj.meta_type(obj.prob, obj.y_ind(i), [], obj.unmatched_params{:});
                end
                
                obj.meta_y = metamodel_int_y;
                
            end
            
            % Launch optimization sequence
            obj.in_a_row = 0;
            obj.Opt();
            
        end
        
        [] = Conv_check_crit( obj );
        [] = Find_min_value( obj );
        [ EI_val, grad_EI ] = Obj_func_EI( obj, x_test );
        [ y_obj ] = Obj_func_nsga( obj, x_test );
        [] = Opt_crit( obj );
        [] = Set_options_optim( obj, user_opt );        
        
    end
    
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


