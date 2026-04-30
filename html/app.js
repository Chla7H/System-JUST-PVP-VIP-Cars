const app = document.getElementById('app');
const carsEl = document.getElementById('cars');
const closeBtn = document.getElementById('closeBtn');
const boostBtn = document.getElementById('boostBtn');
const coinsEl = document.getElementById('coins');
const errorEl = document.getElementById('error');
const serverNameEl = document.getElementById('serverName');
const logoEl = document.getElementById('logo');
const playerInfoEl = document.getElementById('playerInfo');
const tabsEl = document.getElementById('tabs');
const garageTab = document.getElementById('garageTab');
const shopTab = document.getElementById('shopTab');
const adminTab = document.getElementById('adminTab');
const garageView = document.getElementById('garageView');
const shopView = document.getElementById('shopView');
const adminView = document.getElementById('adminView');
const shopEl = document.getElementById('shop');
const adminForm = document.getElementById('adminForm');
const clearFormBtn = document.getElementById('clearFormBtn');
const coinAdminForm = document.getElementById('coinAdminForm');
const grantCarForm = document.getElementById('grantCarForm');
const vaultAdminForm = document.getElementById('vaultAdminForm');
const shopAdminForm = document.getElementById('shopAdminForm');
const clearShopFormBtn = document.getElementById('clearShopFormBtn');
const withdrawVaultBtn = document.getElementById('withdrawVaultBtn');
const carLabel = document.getElementById('carLabel');
const carModel = document.getElementById('carModel');
const carRole = document.getElementById('carRole');
const carCashPrice = document.getElementById('carCashPrice');
const carImage = document.getElementById('carImage');
const carDescription = document.getElementById('carDescription');
const coinTargetId = document.getElementById('coinTargetId');
const coinAmount = document.getElementById('coinAmount');
const grantTargetId = document.getElementById('grantTargetId');
const grantCarModel = document.getElementById('grantCarModel');
const vaultAmount = document.getElementById('vaultAmount');
const boostCashPrice = document.getElementById('boostCashPrice');
const shopPackageId = document.getElementById('shopPackageId');
const shopPackageLabel = document.getElementById('shopPackageLabel');
const shopPackageCoins = document.getElementById('shopPackageCoins');
const shopPackagePrice = document.getElementById('shopPackagePrice');

let currentCars = [];
let currentShop = [];
let isAdmin = false;

const resourceName = typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : 'justpvp_vipcars';

function post(name, data = {}) {
    return fetch(`https://${resourceName}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).then((response) => response.json().catch(() => ({})));
}

function escapeHtml(value) {
    return String(value || '').replace(/[&<>"']/g, (char) => ({
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;'
    }[char]));
}

function setError(message) {
    if (!message) {
        errorEl.classList.add('hidden');
        errorEl.textContent = '';
        return;
    }

    errorEl.textContent = message;
    errorEl.classList.remove('hidden');
}

function setCoins(coins) {
    coinsEl.textContent = Number(coins || 0).toLocaleString('en-US');
}

function getLogoUrl(url) {
    const albumMatch = String(url || '').match(/imgur\.com\/a\/([a-zA-Z0-9]+)/);
    if (albumMatch) {
        return `https://i.imgur.com/${albumMatch[1]}.png`;
    }

    return url || '';
}

function setView(name) {
    const adminActive = name === 'admin';
    const shopActive = name === 'shop';
    garageView.classList.toggle('hidden', adminActive || shopActive);
    shopView.classList.toggle('hidden', !shopActive);
    adminView.classList.toggle('hidden', !adminActive);
    garageTab.classList.toggle('active', !adminActive && !shopActive);
    shopTab.classList.toggle('active', shopActive);
    adminTab.classList.toggle('active', adminActive);

    if (!adminActive) {
        adminView.scrollTop = 0;
    }
}

function fillForm(car = {}) {
    carLabel.value = car.label || '';
    carModel.value = car.model || '';
    carRole.value = car.role || '';
    carCashPrice.value = car.cashPrice || '';
    carImage.value = car.image || '';
    carDescription.value = car.description || '';
    setView('admin');
}

function fillShopForm(package = {}) {
    shopPackageId.value = package.id || '';
    shopPackageLabel.value = package.label || '';
    shopPackageCoins.value = package.coins || '';
    shopPackagePrice.value = package.price || '';
    setView('admin');
}

function renderCars(cars) {
    carsEl.innerHTML = '';

    if (!cars || cars.length === 0) {
        carsEl.innerHTML = '<div class="empty">No VIP cars available for your Discord roles.</div>';
        return;
    }

    for (const car of cars) {
        const item = document.createElement('article');
        item.className = `car ${car.unlocked ? '' : 'locked'}`;
        const image = car.image
            ? `<img class="car-image" src="${escapeHtml(car.image)}" alt="${escapeHtml(car.label)}">`
            : '<div class="car-image placeholder">VIP</div>';

        item.innerHTML = `
            ${image}
            <div class="car-body">
                <h2>${escapeHtml(car.label)}</h2>
                <p>${escapeHtml(car.description || car.model)}</p>
                ${isAdmin ? `<small>${escapeHtml(car.model)} | Role: ${escapeHtml(car.role || 'None')} | Cash: $${Number(car.cashPrice || 0).toLocaleString('en-US')}</small>` : ''}
            </div>
            <div class="car-actions">
                ${car.unlocked
                    ? '<button class="spawn-btn" type="button">Spawn</button>'
                    : car.forSale
                        ? `<button class="buy-car-btn" type="button">Buy $${Number(car.cashPrice || 0).toLocaleString('en-US')}</button>`
                        : '<button class="spawn-btn" type="button" disabled>Locked</button>'}
                ${isAdmin ? '<button class="edit-btn secondary" type="button">Edit</button><button class="delete-btn danger" type="button">Delete</button>' : ''}
            </div>
        `;

        const spawnBtn = item.querySelector('.spawn-btn');
        if (spawnBtn) {
            spawnBtn.addEventListener('click', () => {
                post('spawnCar', { model: car.model });
            });
        }

        const buyCarBtn = item.querySelector('.buy-car-btn');
        if (buyCarBtn) {
            buyCarBtn.addEventListener('click', () => {
                post('buyCar', { model: car.model });
            });
        }

        const editBtn = item.querySelector('.edit-btn');
        if (editBtn) {
            editBtn.addEventListener('click', () => fillForm(car));
        }

        const deleteBtn = item.querySelector('.delete-btn');
        if (deleteBtn) {
            deleteBtn.addEventListener('click', () => {
                post('adminDeleteCar', { model: car.model });
            });
        }

        carsEl.appendChild(item);
    }
}

function renderShop(packages) {
    shopEl.innerHTML = '';

    if (!packages || packages.length === 0) {
        shopEl.innerHTML = '<div class="empty">No coin packages configured.</div>';
        return;
    }

    for (const pack of packages) {
        const item = document.createElement('article');
        item.className = 'shop-card';
        item.innerHTML = `
            <div>
                <h2>${escapeHtml(pack.label)}</h2>
                <strong>${Number(pack.coins || 0).toLocaleString('en-US')} Coins</strong>
                <p>$${Number(pack.price || 0).toLocaleString('en-US')} game money</p>
            </div>
            <div class="shop-actions">
                <button class="buy-package-btn" type="button">Buy</button>
                ${isAdmin ? '<button class="edit-package-btn secondary" type="button">Edit</button><button class="delete-package-btn danger" type="button">Delete</button>' : ''}
            </div>
        `;

        item.querySelector('.buy-package-btn').addEventListener('click', () => {
            post('buyCoins', { id: pack.id });
        });

        const editBtn = item.querySelector('.edit-package-btn');
        if (editBtn) {
            editBtn.addEventListener('click', () => fillShopForm(pack));
        }

        const deleteBtn = item.querySelector('.delete-package-btn');
        if (deleteBtn) {
            deleteBtn.addEventListener('click', () => {
                post('adminDeleteCoinPackage', { id: pack.id });
            });
        }

        shopEl.appendChild(item);
    }
}

function openMenu(payload) {
    const data = payload || {};
    const ui = data.config || {};

    currentCars = data.cars || [];
    currentShop = data.shop || [];
    isAdmin = data.isAdmin === true;

    app.classList.remove('hidden');
    serverNameEl.textContent = ui.ServerName || 'JUST PVP';
    logoEl.src = getLogoUrl(ui.LogoUrl);
    playerInfoEl.textContent = `ID: ${(data.player && data.player.id) || '-'} | Discord: ${(data.player && data.player.discord) || '-'}`;
    setCoins(data.coins);
    vaultAmount.textContent = `$${Number(data.vault || 0).toLocaleString('en-US')}`;
    boostCashPrice.value = data.boostCashPrice || '';
    boostBtn.disabled = data.boostDisabled === true;
    boostBtn.textContent = data.boostDisabled
        ? 'Turbo Locked'
        : data.unlimitedBoost
            ? 'Turbo Max'
            : data.boostCash
                ? `Turbo $${Number(data.boostCashPrice || 0).toLocaleString('en-US')}`
                : `Turbo ${data.boostCost || 100}`;

    tabsEl.classList.remove('hidden');
    adminTab.classList.toggle('hidden', !isAdmin);
    if (!isAdmin) {
        setView('garage');
    }

    renderCars(currentCars);
    renderShop(currentShop);
    garageView.scrollTop = 0;
    shopView.scrollTop = 0;
    adminView.scrollTop = 0;
    setError(data.ok === false ? data.message : '');
}

function closeMenu() {
    app.classList.add('hidden');
}

closeBtn.addEventListener('click', () => post('close'));
boostBtn.addEventListener('click', () => post('buyBoost'));
garageTab.addEventListener('click', () => setView('garage'));
shopTab.addEventListener('click', () => setView('shop'));
adminTab.addEventListener('click', () => setView('admin'));
clearFormBtn.addEventListener('click', () => fillForm({}));
clearShopFormBtn.addEventListener('click', () => fillShopForm({}));

adminForm.addEventListener('submit', (event) => {
    event.preventDefault();
    post('adminSaveCar', {
        label: carLabel.value.trim(),
        model: carModel.value.trim(),
        role: carRole.value.trim(),
        cashPrice: carCashPrice.value.trim(),
        image: carImage.value.trim(),
        description: carDescription.value.trim()
    });
});

coinAdminForm.addEventListener('submit', (event) => {
    event.preventDefault();
    post('adminAddCoins', {
        targetId: coinTargetId.value.trim(),
        amount: coinAmount.value.trim()
    });
});

grantCarForm.addEventListener('submit', (event) => {
    event.preventDefault();
    post('adminGrantCar', {
        targetId: grantTargetId.value.trim(),
        model: grantCarModel.value.trim()
    });
});

shopAdminForm.addEventListener('submit', (event) => {
    event.preventDefault();
    post('adminSaveCoinPackage', {
        id: shopPackageId.value.trim(),
        label: shopPackageLabel.value.trim(),
        coins: shopPackageCoins.value.trim(),
        price: shopPackagePrice.value.trim()
    });
});

vaultAdminForm.addEventListener('submit', (event) => {
    event.preventDefault();
    post('adminSaveSettings', {
        boostCashPrice: boostCashPrice.value.trim()
    });
});

withdrawVaultBtn.addEventListener('click', () => {
    post('adminWithdrawVault');
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        post('close');
    }
});

window.addEventListener('message', (event) => {
    const { action, payload, coins } = event.data || {};

    if (action === 'open') {
        openMenu(payload);
    }

    if (action === 'close') {
        closeMenu();
    }

    if (action === 'coins') {
        setCoins(coins);
    }
});
