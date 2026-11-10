classdef BoardFixture < matlab.unittest.fixtures.Fixture
    % labgrid.fixtures.BoardFixture  Shared fixture that provides a labgrid-booted board.
    %
    %   classdef (SharedTestFixtures={labgrid.fixtures.BoardFixture("adrv9371")}) MyTests < ...
    %
    %   On setup the fixture looks for a lease handed over by `adi-lg request --run` (IIO_URI,
    %   LG_PLACE, LG_CARRIER, HW_DAUGHTER, HW_CARRIER). If one is present and matches Part (or the
    %   hand-over carries no part tag, or Part is empty) it is used as-is. Otherwise the fixture
    %   asks the coordinator for a board through labgrid.Session (interactive path).
    %
    %   For its lifetime the fixture exports the lease as the same environment variables, so test
    %   code that reads getenv("IIO_URI") works identically in CI and interactively.
    %
    %   Fixtures with the same Part and Carrier are compatible: one board serves every class in a
    %   suite that asks for it. Select tests by board with
    %   matlab.unittest.selectors.HasSharedTestFixture(labgrid.fixtures.BoardFixture("adrv9371")).

    properties (SetAccess = immutable)
        Part (1,1) string = ""      % daughter board / part, "" = any board the environment offers
        Carrier (1,1) string = ""   % optional carrier filter
        Wait (1,1) double = 1800    % seconds to queue for a free board (interactive path)
        PowerDown (1,1) logical = false
    end

    properties (SetAccess = private)
        Lease labgrid.Lease = labgrid.Lease.empty(0, 0)
    end

    methods
        function fixture = BoardFixture(part, opts)
            arguments
                part (1,1) string = ""
                opts.Carrier (1,1) string = ""
                opts.Wait (1,1) double = 1800
                opts.PowerDown (1,1) logical = false
            end
            fixture.Part = part;
            fixture.Carrier = opts.Carrier;
            fixture.Wait = opts.Wait;
            fixture.PowerDown = opts.PowerDown;
        end

        function setup(fixture)
            lease = labgrid.Lease.fromEnvironment();
            if ~isempty(lease)
                if strlength(fixture.Part) > 0 && strlength(lease.Daughter) > 0 ...
                        && lease.Daughter ~= fixture.Part
                    fixture.assumeFail(sprintf( ...
                        "Environment lease is for '%s' (place %s) but this fixture needs '%s'.", ...
                        lease.Daughter, lease.Place, fixture.Part));
                end
                if strlength(fixture.Carrier) > 0 && strlength(lease.Carrier) > 0 ...
                        && lease.Carrier ~= fixture.Carrier
                    fixture.assumeFail(sprintf( ...
                        "Environment lease is on carrier '%s' (place %s) but this fixture needs '%s'.", ...
                        lease.Carrier, lease.Place, fixture.Carrier));
                end
            else
                lease = fixture.acquireViaSession();
            end
            fixture.Lease = lease;
            fixture.exportEnvironment(lease);
            fixture.SetupDescription = sprintf("labgrid board %s (%s on %s) at %s [%s]", ...
                lease.Place, lease.Daughter, lease.Carrier, lease.URI, lease.Source);
            fixture.TeardownDescription = sprintf("Releasing labgrid board %s", lease.Place);
        end
    end

    methods (Access = protected)
        function tf = isCompatible(fixture, other)
            tf = fixture.Part == other.Part && fixture.Carrier == other.Carrier;
        end
    end

    methods (Access = private)
        function lease = acquireViaSession(fixture)
            % Interactive path. Any reason the board cannot be had right now (no adi-lg, no
            % coordinator configured, board busy) is an *assumption* failure: the tests are
            % Incomplete, not red. A matching board that exists but fails to boot is an error.
            lease = labgrid.Lease.empty(0, 0);
            if ~labgrid.Session.isAvailable()
                fixture.assumeFail(sprintf( ...
                    "No board lease in the environment and '%s' is not available; run under " + ...
                    "`adi-lg request --part %s --run ...` or install labgrid-plugins.", ...
                    labgrid.config.adiLgBin(), fixture.Part));
            end
            try
                session = labgrid.Session.request(fixture.Part, Carrier=fixture.Carrier, ...
                    Wait=fixture.Wait, PowerDown=fixture.PowerDown);
            catch err
                switch err.identifier
                    case {"labgrid:boardUnavailable", "labgrid:noCoordinator", "labgrid:unsupportedPlatform"}
                        fixture.assumeFail(err.message);
                    otherwise
                        rethrow(err);
                end
            end
            fixture.addTeardown(@() session.release());
            lease = session.Lease;
        end

        function exportEnvironment(fixture, lease)
            env = lease.toEnvironment();
            names = string(fieldnames(env));
            for n = names(:)'
                previous = getenv(n);
                setenv(n, env.(n));
                fixture.addTeardown(@() setenv(n, previous));
            end
        end
    end
end
