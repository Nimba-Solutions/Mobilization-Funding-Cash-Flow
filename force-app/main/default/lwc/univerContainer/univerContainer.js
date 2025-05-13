import { LightningElement, api } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Static Resource
import univer from '@salesforce/resourceUrl/univer';

// Loading states for each dependency
const LOAD_STATES = {
    NOT_STARTED: 'not_started',
    LOADING: 'loading',
    LOADED: 'loaded',
    ERROR: 'error'
};

// Default workbook data
const DEFAULT_WORKBOOK_DATA = {
    id: 'default',
    sheets: [{
        id: 'sheet1',
        name: 'Sheet 1',
        cellData: {},
        rowCount: 1000,
        columnCount: 26
    }],
    name: 'Untitled Workbook',
    appVersion: '3.0.0-alpha',
    sheets: [{
        id: 'sheet1',
        name: 'Sheet 1'
    }],
    locale: 'en-US',
    name: 'Untitled',
    sheetOrder: ['sheet1'],
    styles: {},
    formatConfig: {}
};

export default class UniverContainer extends LightningElement {
    @api recordId;
    @api objectApiName;

    univerInstance;
    workbook;

    // Loading state tracking
    loadingStates = {
        core: LOAD_STATES.NOT_STARTED,
        sheets: LOAD_STATES.NOT_STARTED,
        docs: LOAD_STATES.NOT_STARTED,
        engineRender: LOAD_STATES.NOT_STARTED,
        engineFormula: LOAD_STATES.NOT_STARTED,
        sheetsUi: LOAD_STATES.NOT_STARTED,
        docsUi: LOAD_STATES.NOT_STARTED,
        sheetsFacade: LOAD_STATES.NOT_STARTED
    };

    // Error tracking
    errors = [];

    // Loading sequence definition with dependencies
    loadingSequence = [
        { name: 'core', path: '/core.js' },
        { name: 'engineRender', path: '/engine-render.js', depends: ['core'] },
        { name: 'engineFormula', path: '/engine-formula.js', depends: ['core'] },
        { name: 'sheets', path: '/sheets.js', depends: ['core', 'engineRender', 'engineFormula'] },
        { name: 'docs', path: '/docs.js', depends: ['core', 'engineRender'] },
        { name: 'sheetsUi', path: '/sheets-ui.js', depends: ['sheets'] },
        { name: 'docsUi', path: '/docs-ui.js', depends: ['docs'] },
        { name: 'sheetsFacade', path: '/sheets-facade.js', depends: ['sheets', 'sheetsUi'] }
    ];

    connectedCallback() {
        this.logMessage('info', 'UniverContainer initialization started');
        // Wait for the DOM to be ready
        Promise.resolve().then(() => this.loadUniver());
    }

    /**
     * Main loading sequence for Univer
     */
    async loadUniver() {
        try {
            // Reset states
            this.errors = [];
            this.loadingStates = Object.fromEntries(
                Object.keys(this.loadingStates).map(key => [key, LOAD_STATES.NOT_STARTED])
            );

            // Load core first
            await this.loadResource(this.loadingSequence[0]);

            // Load remaining resources in parallel, respecting dependencies
            const remainingResources = this.loadingSequence.slice(1);
            await Promise.all(
                remainingResources.map(async resource => {
                    // Wait for dependencies
                    if (resource.depends) {
                        await Promise.all(
                            resource.depends.map(dep => 
                                this.waitForResourceLoad(dep)
                            )
                        );
                    }
                    return this.loadResource(resource);
                })
            );
            
            this.logMessage('success', 'All Univer resources loaded successfully');
            
            // Update loading status
            this.loadingStates = Object.fromEntries(
                Object.keys(this.loadingStates).map(key => [key, LOAD_STATES.LOADED])
            );

            // Wait for next render cycle and initialize
            await this.initializeUniver();
        } catch (error) {
            this.logMessage('error', 'Failed to load Univer resources', error);
            this.showErrorToast('Failed to load Univer', error.message);
        }
    }

    /**
     * Wait for a resource to be loaded
     */
    waitForResourceLoad(resourceName) {
        return new Promise((resolve, reject) => {
            const checkState = () => {
                const state = this.loadingStates[resourceName];
                if (state === LOAD_STATES.LOADED) {
                    resolve();
                } else if (state === LOAD_STATES.ERROR) {
                    reject(new Error(`Dependency ${resourceName} failed to load`));
                } else {
                    setTimeout(checkState, 100);
                }
            };
            checkState();
        });
    }

    /**
     * Load a single resource with state tracking
     */
    async loadResource({ name, path }) {
        this.logMessage('info', `Loading ${name}...`);
        
        this.loadingStates = {
            ...this.loadingStates,
            [name]: LOAD_STATES.LOADING
        };

        try {
            await loadScript(this, univer + path);
            
            this.loadingStates = {
                ...this.loadingStates,
                [name]: LOAD_STATES.LOADED
            };
            
            this.logMessage('success', `${name} loaded successfully`);
        } catch (error) {
            this.loadingStates = {
                ...this.loadingStates,
                [name]: LOAD_STATES.ERROR
            };
            
            this.errors.push({ resource: name, error });
            this.logMessage('error', `Failed to load ${name}`, error);
            throw new Error(`Failed to load ${name}: ${error.message}`);
        }
    }

    /**
     * Initialize Univer after all resources are loaded
     */
    async initializeUniver() {
        try {
            this.logMessage('info', 'Initializing Univer...');
            
            // Ensure container is ready
            await new Promise(resolve => requestAnimationFrame(resolve));
            
            const container = this.template.querySelector('.univer-workspace');
            if (!container) {
                throw new Error('Container element not found');
            }

            // Initialize with required configuration using the correct API
            const univer = new window.Univer({
                theme: window.defaultTheme,
                locale: 'en-US',
                container: container
            });

            // Register required plugins
            univer.registerPlugin(window.UniverSheetsPlugin);
            univer.registerPlugin(window.UniverFormulaEnginePlugin);
            univer.registerPlugin(window.UniverRenderEnginePlugin);
            univer.registerPlugin(window.UniverUIPlugin, {
                container: container
            });

            // Create workbook
            this.univerInstance = univer;
            this.workbook = univer.createUnit(window.UniverInstanceType.UNIVER_SHEET, DEFAULT_WORKBOOK_DATA);
            
            this.logMessage('success', 'Univer initialized successfully');
        } catch (error) {
            this.logMessage('error', 'Failed to initialize Univer', error);
            this.showErrorToast('Failed to initialize Univer', error.message);
            throw error;
        }
    }

    /**
     * Logging utility that handles both console and custom event dispatch
     */
    logMessage(level, message, error = null) {
        const timestamp = new Date().toISOString();
        const logMessage = `[Univer] ${timestamp} - ${message}`;
        const errorDetails = error ? JSON.stringify(error, Object.getOwnPropertyNames(error)) : null;
        
        // Console logging
        switch (level) {
            case 'error':
                console.error(logMessage, errorDetails);
                break;
            case 'warning':
                console.warn(logMessage);
                break;
            case 'success':
                console.log('%c' + logMessage, 'color: green');
                break;
            default:
                console.log(logMessage);
        }

        // Dispatch custom event for external logging
        this.dispatchEvent(new CustomEvent('univerlog', {
            detail: {
                level,
                message,
                timestamp,
                error: errorDetails
            },
            bubbles: true,
            composed: true
        }));
    }

    /**
     * Show error toast message
     */
    showErrorToast(title, message) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant: 'error'
        }));
    }

    /**
     * Get loading status for template
     */
    get loadingStatus() {
        const total = Object.keys(this.loadingStates).length;
        const loaded = Object.values(this.loadingStates)
            .filter(state => state === LOAD_STATES.LOADED).length;
        
        return {
            isComplete: loaded === total && total > 0,
            progress: total > 0 ? Math.round((loaded / total) * 100) : 0,
            hasErrors: this.errors.length > 0
        };
    }
} 