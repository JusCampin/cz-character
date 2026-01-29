window._czDebug = window._czDebug || false
window.addEventListener('message', function(event){
    const d = event.data
    if(!d) return
    if (window._czDebug) console.log('cz-character NUI received', d && d.action)
    if (d.resource) window._czResourceName = d.resource
    if (typeof d.dev !== 'undefined') window._czDebug = !!d.dev

    if(d.action === 'open'){
        document.getElementById('app').classList.remove('hidden')
    }
    if(d.action === 'close'){
        document.getElementById('app').classList.add('hidden')
    }
    if(d.action === 'setCharacters'){
        if (d.resource) window._czResourceName = d.resource
        const list = document.getElementById('list')
        list.innerHTML = ''
        ;(d.characters||[]).forEach(function(c){
            const el = document.createElement('div')
            el.className = 'char'
            el.innerHTML = '<div><b>' + (c.first_name||'Unnamed') + (c.last_name?(' ' + c.last_name):'') + '</b><div class="meta">ID: ' + c.id + '</div></div>'

            const btnSelect = document.createElement('button')
            btnSelect.className = 'cz-select'
            btnSelect.dataset.id = c.id
            btnSelect.innerText = 'Select'
            el.appendChild(btnSelect)

            const btnEdit = document.createElement('button')
            btnEdit.className = 'cz-edit'
            btnEdit.dataset.id = c.id
            btnEdit.dataset.first = c.first_name || ''
            btnEdit.dataset.last = c.last_name || ''
            btnEdit.style.marginLeft = '6px'
            btnEdit.innerText = 'Edit'
            el.appendChild(btnEdit)

            list.appendChild(el)
        })
    }
})

document.getElementById('list').addEventListener('click', function(ev){
    const target = ev.target
    const resName = window._czResourceName || GetParentResourceName()
    if (target && target.classList && target.classList.contains('cz-select')){
        const id = target.dataset.id
        if (window._czDebug) console.log('cz-character: select clicked (delegated)', resName, id)
        fetch(`https://${resName}/selectCharacter`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ id: id }) }).catch(function(err){ console.error('fetch error', err) })
        return
    }
    if (target && target.classList && target.classList.contains('cz-edit')){
            try {
            const id = target.dataset.id
            const firstDefault = target.dataset.first || ''
            const lastDefault = target.dataset.last || ''
            if (window._czDebug) console.log('cz-character: edit clicked (delegated)', resName, id, firstDefault, lastDefault)
            openEditModal(id, firstDefault, lastDefault, resName)
        } catch (e) { console.error('delegated edit handler error', e) }
        return
    }
})

document.getElementById('close').addEventListener('click', function(){
    try {
        const resName = window._czResourceName || GetParentResourceName()
        if (window._czDebug) console.log('cz-character: close clicked, posting to', resName)
        // request close from client; only hide UI if client accepts
        fetch(`https://${resName}/close`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({}) })
            .then(function(resp){
                if (!resp) return
                return resp.text().then(function(text){
                    if (window._czDebug) console.log('cz-character: close callback response', text)
                    if (text === 'ok'){
                        document.getElementById('app').classList.add('hidden')
                    } else {
                        // keep open; optionally notify user
                        console.warn('cz-character: close denied by client')
                    }
                })
            })
            .catch(function(err){ console.error('fetch error', err) })
    } catch (e) { console.error('fetch exception', e) }
})

// helper provided by FiveM environment
function GetParentResourceName(){
    var parts = window.location.pathname.split('/')
    if (parts.length > 1 && parts[1] && parts[1] !== 'html') return parts[1]
    if (parts.length > 2 && parts[2] && parts[2] !== 'html') return parts[2]
    // try extracting resource from href like '/resourceName/html/index.html'
    var m = window.location.href.match(/\/([^\/]+)\/html\//)
    if (m && m[1]) return m[1]
    return ''
}

// Non-blocking edit modal to avoid browser prompt() freezing NUI
function openEditModal(id, firstDefault, lastDefault, resName){
    // remove existing modal if present
    const existing = document.getElementById('cz-edit-modal')
    if (existing) existing.remove()

    const modal = document.createElement('div')
    modal.id = 'cz-edit-modal'
    modal.style.position = 'fixed'
    modal.style.left = '0'
    modal.style.top = '0'
    modal.style.right = '0'
    modal.style.bottom = '0'
    modal.style.display = 'flex'
    modal.style.alignItems = 'center'
    modal.style.justifyContent = 'center'
    modal.style.background = 'rgba(0,0,0,0.6)'
    modal.style.zIndex = '9999'

    const box = document.createElement('div')
    box.style.background = '#222'
    box.style.padding = '12px'
    box.style.borderRadius = '6px'
    box.style.minWidth = '320px'
    box.style.color = '#fff'

    const title = document.createElement('div')
    title.innerText = 'Edit Character'
    title.style.marginBottom = '8px'
    box.appendChild(title)

    const inFirst = document.createElement('input')
    inFirst.type = 'text'
    inFirst.value = firstDefault || ''
    inFirst.placeholder = 'First name'
    inFirst.style.width = '100%'
    inFirst.style.marginBottom = '6px'
    box.appendChild(inFirst)

    const inLast = document.createElement('input')
    inLast.type = 'text'
    inLast.value = lastDefault || ''
    inLast.placeholder = 'Last name (optional)'
    inLast.style.width = '100%'
    inLast.style.marginBottom = '10px'
    box.appendChild(inLast)

    const row = document.createElement('div')
    row.style.display = 'flex'
    row.style.justifyContent = 'flex-end'

    const btnCancel = document.createElement('button')
    btnCancel.innerText = 'Cancel'
    btnCancel.style.marginRight = '8px'
    btnCancel.onclick = function(){ modal.remove() }
    row.appendChild(btnCancel)

    const btnOk = document.createElement('button')
    btnOk.innerText = 'Save'
            btnOk.onclick = function(){
        try {
            const first = inFirst.value || ''
            const last = inLast.value || ''
            if (window._czDebug) console.log('cz-character: edit modal save', resName, id, first, last)
            fetch(`https://${resName}/editCharacter`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ id: id, first: first, last: last }) })
                .then(function(){ fetch(`https://${resName}/requestCharacters`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({}) }).catch(function() {}) })
                .catch(function(err){ console.error('fetch error', err) })
        } catch (e) { console.error('edit modal exception', e) }
        modal.remove()
    }
    row.appendChild(btnOk)

    box.appendChild(row)
    modal.appendChild(box)
    document.body.appendChild(modal)
    inFirst.focus()
}
