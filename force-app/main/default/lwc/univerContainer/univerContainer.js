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

export default class UniverContainer extends LightningElement {
    @api recordId;
    @api objectApiName;

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

    // Loading sequence definition
    loadingSequence = [
        { name: 'core', path: '/univer-core.js' },
        { name: 'engineRender', path: '/univer-engine-render.js' },
        { name: 'engineFormula', path: '/univer-engine-formula.js' },
        { name: 'sheets', path: '/univer-sheets.js' },
        { name: 'docs', path: '/univer-docs.js' },
        { name: 'sheetsUi', path: '/univer-sheets-ui.js' },
        { name: 'docsUi', path: '/univer-docs-ui.js' },
        { name: 'sheetsFacade', path: '/univer-sheets-facade.js' }
    ];

    connectedCallback() {
        this.logMessage('info', 'UniverContainer initialization started');
        this.loadUniver();
    }

    /**
     * Main loading sequence for Univer
     */
    async loadUniver() {
        try {
            for (const resource of this.loadingSequence) {
                await this.loadResource(resource);
            }
            
            this.logMessage('success', 'All Univer resources loaded successfully');
            this.initializeUniver();
        } catch (error) {
            this.logMessage('error', 'Failed to load Univer resources', error);
            this.showErrorToast('Failed to load Univer', error.message);
        }
    }

    /**
     * Load a single resource with state tracking
     */
    async loadResource({ name, path }) {
        this.logMessage('info', `Loading ${name}...`);
        this.loadingStates[name] = LOAD_STATES.LOADING;

        try {
            await loadScript(this, univer + path);
            this.loadingStates[name] = LOAD_STATES.LOADED;
            this.logMessage('success', `${name} loaded successfully`);
        } catch (error) {
            this.loadingStates[name] = LOAD_STATES.ERROR;
            this.errors.push({ resource: name, error });
            this.logMessage('error', `Failed to load ${name}`, error);
            throw new Error(`Failed to load ${name}: ${error.message}`);
        }
    }

    /**
     * Initialize Univer after all resources are loaded
     */
    initializeUniver() {
        try {
            this.logMessage('info', 'Initializing Univer...');
            // TODO: Initialize Univer instance
            this.logMessage('success', 'Univer initialized successfully');
        } catch (error) {
            this.logMessage('error', 'Failed to initialize Univer', error);
            this.showErrorToast('Failed to initialize Univer', error.message);
        }
    }

    /**
     * Logging utility that handles both console and custom event dispatch
     */
    logMessage(level, message, error = null) {
        const timestamp = new Date().toISOString();
        const logMessage = `[Univer] ${timestamp} - ${message}`;
        
        // Console logging
        switch (level) {
            case 'error':
                console.error(logMessage, error);
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
                error: error ? error.message : null
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
            isComplete: loaded === total,
            progress: Math.round((loaded / total) * 100),
            hasErrors: this.errors.length > 0
        };
    }
} 