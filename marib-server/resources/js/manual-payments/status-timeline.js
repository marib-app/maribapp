const POLL_INTERVAL_FALLBACK = 8000;

function parseJsonAttribute(element, attribute) {
    const value = element.dataset[attribute];

    if (!value) {
        return null;
    }

    try {
        return JSON.parse(value);
    } catch (error) {
        console.warn('Manual payment timeline: failed to parse data attribute', attribute, error);
        return null;
    }
}

function renderTimelineEntry(entry) {
    const entryElement = document.createElement('div');
    entryElement.className = 'manual-payment-timeline-entry';

    if (entry.is_current) {
        entryElement.classList.add('is-current');
    }

    const marker = document.createElement('div');
    marker.className = 'manual-payment-timeline-marker';

    const icon = document.createElement('i');
    icon.className = entry.icon || 'fa-solid fa-circle text-secondary';
    icon.setAttribute('aria-hidden', 'true');
    marker.appendChild(icon);

    const content = document.createElement('div');
    content.className = 'manual-payment-timeline-content';

    const header = document.createElement('div');
    header.className = 'manual-payment-timeline-header';

    const title = document.createElement('div');
    title.className = 'manual-payment-timeline-title';
    title.textContent = entry.status_label || entry.status || '';

    const meta = document.createElement('div');
    meta.className = 'manual-payment-timeline-meta';
    const metaParts = [];

    if (entry.actor) {
        metaParts.push(entry.actor);
    }

    if (entry.created_at_human) {
        metaParts.push(entry.created_at_human);
    }

    meta.textContent = metaParts.join(' • ');

    header.appendChild(title);
    header.appendChild(meta);

    content.appendChild(header);

    if (entry.note) {
        const note = document.createElement('p');
        note.className = 'manual-payment-timeline-note mb-0';
        note.textContent = entry.note;
        content.appendChild(note);
    }

    if (entry.attachment_url) {
        const attachmentWrapper = document.createElement('div');
        attachmentWrapper.className = 'manual-payment-timeline-attachment mt-2';

        const attachmentLink = document.createElement('a');
        attachmentLink.className = 'btn btn-sm btn-outline-secondary';
        attachmentLink.href = entry.attachment_url;
        attachmentLink.target = '_blank';
        attachmentLink.rel = 'noopener';

        const attachmentIcon = document.createElement('i');
        attachmentIcon.className = 'fa-solid fa-paperclip me-1';
        attachmentIcon.setAttribute('aria-hidden', 'true');
        attachmentLink.appendChild(attachmentIcon);

        const attachmentText = document.createElement('span');
        attachmentText.textContent = entry.attachment_label || entry.attachment_name || 'View attachment';
        attachmentLink.appendChild(attachmentText);

        attachmentWrapper.appendChild(attachmentLink);
        content.appendChild(attachmentWrapper);
    }

    if (entry.notification_sent) {
        const notification = document.createElement('div');
        notification.className = 'manual-payment-timeline-notification text-muted small mt-2';

        const notificationIcon = document.createElement('i');
        notificationIcon.className = 'fa-solid fa-bell me-1';
        notificationIcon.setAttribute('aria-hidden', 'true');
        notification.appendChild(notificationIcon);

        const notificationText = document.createElement('span');
        notificationText.textContent = entry.notification_label || 'Notification sent';
        notification.appendChild(notificationText);

        content.appendChild(notification);
    }

    if (entry.document_valid_until_human) {
        const documentBadge = document.createElement('div');
        documentBadge.className = 'manual-payment-timeline-document';

        const documentIcon = document.createElement('i');
        documentIcon.className = 'fa-solid fa-id-card-clip';
        documentIcon.setAttribute('aria-hidden', 'true');
        documentBadge.appendChild(documentIcon);

        const documentText = document.createElement('span');
        documentText.textContent = entry.document_valid_label
            || entry.document_valid_until_human;
        documentBadge.appendChild(documentText);

        content.appendChild(documentBadge);
    }

    entryElement.appendChild(marker);
    entryElement.appendChild(content);

    return entryElement;
}

function renderTimeline(container, data) {
    if (!data) {
        return;
    }

    const itemsContainer = container.querySelector('[data-timeline-items]');
    const feedbackElement = container.querySelector('[data-timeline-feedback]');
    const badgeElement = container.querySelector('[data-timeline-current-badge]');
    const badgeLabel = container.querySelector('[data-timeline-current-label]');
    const badgeIcon = container.querySelector('[data-timeline-current-icon]');
    const updatedElement = container.querySelector('[data-timeline-updated]');

    if (feedbackElement) {
        feedbackElement.textContent = '';
    }

    if (badgeElement) {
        badgeElement.className = `badge ${data.current_status_badge || 'bg-secondary'}`;
    }

    if (badgeLabel) {
        badgeLabel.textContent = data.current_status_label || '';
    }

    if (badgeIcon) {
        badgeIcon.className = data.current_status_icon || '';
        badgeIcon.setAttribute('aria-hidden', 'true');
    }

    if (updatedElement) {
        updatedElement.textContent = data.last_updated_at_human
            ? `${updatedElement.dataset.prefix || ''}${data.last_updated_at_human}`.trim()
            : '';
    }

    if (!itemsContainer) {
        return;
    }

    itemsContainer.innerHTML = '';

    const entries = Array.isArray(data.timeline) ? data.timeline : [];

    if (!entries.length) {
        const emptyMessage = document.createElement('p');
        emptyMessage.className = 'text-muted mb-0';
        emptyMessage.textContent = data.empty_message || '';
        itemsContainer.appendChild(emptyMessage);
        return;
    }

    entries.forEach((entry) => {
        const entryElement = renderTimelineEntry(entry);
        itemsContainer.appendChild(entryElement);
    });
}

function startTimelinePolling(container, endpoint, interval, onData) {
    let currentSignature = null;
    let timer = null;

    const fetchData = () => {
        if (!endpoint) {
            return;
        }

        fetch(endpoint, {
            credentials: 'same-origin',
            headers: {
                'Accept': 'application/json',
            },
        })
            .then((response) => {
                if (!response.ok) {
                    throw new Error(`Timeline request failed with status ${response.status}`);
                }

                return response.json();
            })
            .then((payload) => {
                const data = payload?.data || payload;
                const signature = JSON.stringify(data);

                if (signature !== currentSignature) {
                    currentSignature = signature;
                    onData(data);
                }
            })
            .catch((error) => {
                console.warn('Manual payment timeline polling failed', error);
                const feedbackElement = container.querySelector('[data-timeline-feedback]');

                if (feedbackElement) {
                    feedbackElement.textContent = container.dataset.errorMessage
                        || 'Unable to refresh the status timeline right now.';
                }
            });
    };

    const start = () => {
        fetchData();
        timer = window.setInterval(fetchData, interval);
    };

    const stop = () => {
        if (timer) {
            window.clearInterval(timer);
            timer = null;
        }
    };

    container.addEventListener('manual-payment-timeline:refresh', fetchData);
    container.addEventListener('manual-payment-timeline:stop', stop);
    container.addEventListener('manual-payment-timeline:start', () => {
        if (!timer) {
            start();
        }
    });

    start();
}

function initManualPaymentTimeline(container) {
    const endpoint = container.dataset.endpoint || container.dataset.timelineEndpoint;
    const interval = Number.parseInt(container.dataset.pollInterval || '', 10)
        || POLL_INTERVAL_FALLBACK;
    const initialState = parseJsonAttribute(container, 'initialState');

    if (initialState) {
        renderTimeline(container, initialState);
    }

    startTimelinePolling(container, endpoint, interval, (data) => {
        renderTimeline(container, data);
    });
}

export default function initManualPaymentTimelines() {
    const containers = document.querySelectorAll('[data-manual-payment-timeline]');

    containers.forEach((container) => {
        if (container.__manualPaymentTimelineInitialized) {
            return;
        }

        container.__manualPaymentTimelineInitialized = true;
        initManualPaymentTimeline(container);
    });
}

if (typeof document !== 'undefined') {
    document.addEventListener('DOMContentLoaded', () => {
        initManualPaymentTimelines();
    });
}