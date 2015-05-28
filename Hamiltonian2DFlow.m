%HAMILTONIAN2DFLOW
%
% Abstract class specifying interface of a "continuous-time" Hamiltonian
% system in terms of its stream function Psi.

classdef (Abstract) Hamiltonian2DFlow < ContinuousFlows.ODEFlow

  methods (Abstract)

    [out] = Psi( obj, t, x, o )
    % PSI Compute the stream function or its derivatives along a
    % trajectory given by (t, x)
    % [ out ] = Psi( obj, t, x, order )
    %
    % t   - row-vector of times
    % x   - trajectory
    %     - columns correspond to time steps
    %     - rows correspond to states
    % o   - order of calculation
    %
    % Returns:
    % out   - evaluation of the stream function or its derivatives
    %       - if o == 0, out is 1 x Nx row vector
    %       - if o == 1, out is 2 x Nx row vector; rows are x and y derivatives
    %                    respectively
    %       - if o == 2, out is 3 x Nx row vector; rows are xx, xy, yy
    %                    derivatives respectively

  end

  methods

    function [ f ] = vf( obj, t, x )
    % VF Compute the vector field along a single
    % trajectory given by (t, x)
    % [ f ] = vf( obj, t, x )
    %
    % t   - row-vector of times
    % x   - trajectory
    %     - columns correspond to time steps
    %     - rows correspond to states
    %
    % Returns:
    % f   - evaluation of the vector field
    %     - each f(:,i) is a dim x 1 vector field evaluation
    %     - of the vector field at [ t(i), x(i,:) ] point

    % system is Hamiltonian (has a stream function)
      f = flipud(obj.Psi(t,x,1)); % exchange rows
      f(1,:) = -f(1,:);
    end

    function [J] = jacobian( obj, t, x )
    % JACOBIAN Compute Jacobian of the vector field along
    % a single trajectory given by (t, x)
    % [ J ] = jacobian( obj, t, x )
    %
    % t   - row-vector of times
    % x   - trajectory
    %     - columns correspond to time steps
    %     - rows correspond to states
    % Returns:
    % J   - Jacobians
    %     - each J(:,:,i) is a dim x dim Jacobian matrix
    %     - of the vector field at [ t(i), x(i,:) ] point

      Nx = size(x,2);
      Jv = obj.Psi(t,x,2);

      J = zeros(2,2,Nx);

      J(1,1,:) = -Jv(2,:);
      J(2,2,:) =  Jv(2,:);
      J(1,2,:) = -Jv(3,:);
      J(2,1,:) =  Jv(1,:);

    end

    function [Omega] = vorticity( obj, t, x )
    % VORTICITY Compute vorticity of the vector field along
    % a single trajectory given by (t, x)
    % [ Omega ] = vorticity( obj, t, x )
    %
    % t   - row-vector of times
    % x   - trajectory
    %     - columns correspond to time steps
    %     - rows correspond to states
    % Returns:
    % Omega  - vorticity row vector, each element corresponds to vorticity
    % at the slice ( t(i), x(:,i) )

      Nx = size(x,2);
      Psiv = obj.Psi(t,x,2);
      Omega = Psiv(1,:) + Psiv(3,:);

    end


    function [ err ] = testPsi( obj, t, x, o, delta )
    %TESTPSI Compute difference between numeric and analytic derivatives of
    %        Psi.
    %
    % The intended use is to verify correctness of analytic expressions in the
    % derivatives of the stream function.
    %
    % err = obj.testPsi( t, x, o )
    % Compute the difference between Psi(t,x,o) and numerical
    % central-difference of Psi(t,x,o-1) at a single space-time point
    % (t,x).
    %
    % err = obj.testPsi( ..., delta )
    % Uses explicit spatial step delta (default is 1e-6)
    %
    % The difference is returned as err.

      if nargin < 5
        delta = 1e-6;
      end
      Nx = size(x,2);

      assert( o >= 1, 'Order has to be >= 1');
      assert( Nx == 1, 'Single point x has to be provided');
      assert( numel(t) == 1, 'Single point t has to be provided');

      %% analytic derivative
      aPsiD = obj.Psi( t, x, o );

      %% central difference
      stencil = eye(2)*delta;
      xi = [bsxfun(@plus, x, stencil), ...
            bsxfun(@minus, x, stencil) ];

      ti = repmat( t, [1, size(xi,2)] );
      nPsi = obj.Psi( ti, xi, o-1 );
      nPsiD = ( nPsi( :, 1:2) - nPsi( :, 3:4) )/(2*delta);

      if size(nPsiD,1) == 1
        nPsiD = nPsiD(:);
      elseif size(nPsiD,1) == 2
        % the off-diagonal elements can be different
        nPsiD1 = [nPsiD(1,1); nPsiD(2,1); nPsiD(2,2)];
        nPsiD2 = [nPsiD(1,1); nPsiD(1,2); nPsiD(2,2)];
        nPsiD = [nPsiD1,nPsiD2];
      end

      %% compute the error
      err = bsxfun( @minus, aPsiD, nPsiD );
    end

    function [varargout] = quiver( obj, t, xi, yi )
    %QUIVER Vector field of the flow.
    %
    % Produce vector field of the flow at time t on the tensor product grid
    % xi XX yi
    %
    % QUIVER(obj, t, xi, yi)
    %   Plots the vector field at time t on a tensor grid xi XX yi
    % h = QUIVER(obj, t, xi, yi)
    %   As above, and returns graphics handle of the quiver object.
    % [X,Y,U,V] = QUIVER(obj, t, xi, yi)
    %   Returns spatial points and components of the vector field.

      if nargin < 3
        R = 20;
        xi = linspace(obj.Domain(1,1), obj.Domain(1,2), R);
        yi = linspace(obj.Domain(2,1), obj.Domain(2,2), R);
      end

      [X,Y] = meshgrid(xi, yi);
      f = obj.vf(t, [X(:),Y(:)].');

      U = reshape(f(1,:), size(X));
      V = reshape(f(2,:), size(Y));

      if nargout > 1
        varargout = {X,Y,U,V};
      else
        h = quiver(X,Y,U,V);
        if nargout > 0
          varargout = h;
        end
      end

    end

    function [varargout] = streamplot( obj, t, xi, yi)
    %STREAM Level sets of the stream function of the flow.
    %
    % STREAMPLOT( obj, t, xi, yi)
    %   Plots the stream function at time t on a tensor grid xi XX yi
    % h = STREAMPLOT(obj, t, xi, yi)
    %   As above, and returns graphics handle of the contourf object.
    % [X,Y,PSI] = STREAMPLOT(obj, t, xi, yi)
    %   Returns spatial points and components of the vector field.

      if nargin < 3
        R = 100;
        xi = linspace(obj.Domain(1,1), obj.Domain(1,2), R);
        yi = linspace(obj.Domain(2,1), obj.Domain(2,2), R);
      end

      [X,Y] = meshgrid(xi, yi);

      x = [X(:),Y(:)].';

      Psiv = reshape(obj.Psi(t,x,0),size(X));

      if nargout > 1
        varargout = {X,Y,Psiv};
      else
        [C,h] = contourf(X,Y,Psiv);
        if nargout > 0
          varargout = h;
        end
      end
    end

    function [varargout] = vorticityplot( obj, t, xi, yi)
    %VORTICITYPLOT Level sets of the vorticity of the flow.
    %
    % VORTICITYPLOT( obj, t, xi, yi)
    %   Plots the vorticity at time t on a tensor grid xi XX yi
    % h = VORTICITYPLOT(obj, t, xi, yi)
    %   As above, and returns graphics handle of the contourf object.
    % [X,Y,PSI] = VORTICITYPLOT(obj, t, xi, yi)
    %   Returns spatial points and components of the vorticity.

      if nargin < 3
        R = 100;
        xi = linspace(obj.Domain(1,1), obj.Domain(1,2), R);
        yi = linspace(obj.Domain(2,1), obj.Domain(2,2), R);
      end

      [X,Y] = meshgrid(xi, yi);

      x = [X(:),Y(:)].';

      Omega = obj.vorticity(t,x);
      Omega = reshape(Omega,size(X));

      if nargout > 1
        varargout = {X,Y,Omega};
      else
        [C,h] = contourf(X,Y,Omega);
        if nargout > 0
          varargout = h;
        end
      end
    end


  end

end
