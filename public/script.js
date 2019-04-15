var app = new Vue({
    el: "#app",
    data: {
        last_deploy_timestamp: "2018-08-01 00:00:01",
        href_prefix: "http://",
        href_postfix: ".test.bowdoinorient.co",
        ajax_prefix: window.location.origin + "/",

        devenv_form_visible: false,
        new_devenv_subdomain: "",
        new_devenv_user: "",
        new_devenv_notes: "",

        deleting: null,

        loading: true,

        devenvs: [
            {
                subdomain: 'master',
                last_updated: "2018-08-01 00:00:01",
                more_text: "Continuously pulls from the master branch.",
            }
        ],

        info_visible: false,
        upload_code: "",
        download_code: "",
        mysql_username: "",
        mysql_password: "",
    },

    filters: {
        reldate: function(timestamp) {
            return moment(timestamp).fromNow()
        }
    },

    methods: {
        generate_download: function(sd, who) {
            return "rsync -ar0 --delete-before dev@deploy.bowdoinorient.co:/var/www/wordpress/" + sd + " ."
        },

        generate_upload: function(sd, who) {
            return "rsync -arO --delete-before . " + who + "@deploy.bowdoinorient.co:/var/www/wordpress/" + sd
        },

        deploy_master: function() {
            this.loading = true
            axios.get(this.ajax_prefix + 'deploy_master')
            .then(function() {
                app.loading = false
            })
        },

        update_master: function() {
            this.loading = true
            axios.get(this.ajax_prefix + 'update_master')
            .then(function() {
                app.loading = false
            })
        },

        get_devenvs: function() {
        },

        new_devenv_confirm: function(subdomain, other_info) {
            this.loading = true
            this.devenv_form_visible = false

            var subdomain = this.new_devenv_subdomain
            var who = this.new_devenv_user
            var notes = this.new_devenv_notes
            this.new_devenv_subdomain = ""

            if(subdomain == "" || who == "") {
                alert("Enter a subdomain and/or a person");
                return;
            }

            axios.get(this.ajax_prefix + 'new_devenv?subdomain=' + subdomain + '&creator=' + who + '&notes=' + notes)
            .then(function(res) {
                app.devenvs.push(res.data)

                app.download_code = app.generate_download(res.data["subdomain"], res.data["creator"])
                app.upload_code = app.generate_upload(res.data["subdomain"], res.data["creator"])

                app.mysql_username = res.data["subdomain"]
                app.mysql_password = res.data["sql_password"]

                app.info_visible = true
            }).catch(function(err) {
                alert(err)
            }).then(function() {
                app.loading = false
            })
        },

        info_env: function(sd) {
            devenv = this.devenvs.filter(function(env) {
                return env.subdomain == sd
            })[0]

            app.download_code = this.generate_download(devenv.subdomain, devenv.creator)
            app.upload_code = this.generate_upload(devenv.subdomain, devenv.creator)
            app.mysql_username = sd
            app.mysql_password = devenv["sql_password"]
            app.info_visible = true
        },

        delete_env: function(sd) {
            this.deleting = null;
            if(sd == "master") {
                return
            }

            this.devenvs = this.devenvs.filter(function(el) {
                return el.subdomain != sd
            });

            app.info_visible = false
            app.loading = true

            axios.get(this.ajax_prefix + 'delete_devenv?subdomain=' + sd)
            .then(function() {
                app.loading = false
            })
        }
    },

    created: function() {
        axios.get(this.ajax_prefix + 'devenvs').then(function(res) {
            app.devenvs = app.devenvs.concat(res.data)
        })
        .catch(function(err) {
            alert(err)
        })
        .then(function() {
            app.loading = false
        })
    }
});


