FROM debian:bullseye

ARG user_name
ARG git_user_name
ARG git_user_email

ARG USER_UID=1000
ARG USER_GID=$USER_UID

SHELL ["/bin/bash", "--login", "-c"]

RUN apt-get update && apt-get install -y autoconf automake build-essential cmake curl git-core gnupg jq libavdevice-dev libboost-dev libncurses5-dev libopencore-amrnb-dev libopencore-amrwb-dev libopus-dev libpcap-dev libsdl2-dev libspeex-dev libssl-dev libswscale-dev libtiff-dev libtool libtool-bin libv4l-dev libvo-amrwbenc-dev locales nano net-tools ngrep pkg-config python-dev rsyslog ruby subversion sudo swig tcpdump tmux tree uuid-dev vim wget tmuxinator xmlstarlet default-jdk doxygen mono-complete libxml2-utils
 
# install sip-lab deps
RUN apt-get -y install build-essential automake autoconf libtool libspeex-dev libopus-dev libsdl2-dev libavdevice-dev libswscale-dev libv4l-dev libopencore-amrnb-dev libopencore-amrwb-dev libvo-amrwbenc-dev libvo-amrwbenc-dev libboost-dev libtiff-dev libpcap-dev libssl-dev uuid-dev flite-dev cmake git wget 

# install sngrep deps
RUN apt-get -y install libpcap-dev libncurses5 libssl-dev libncursesw5-dev libpcre2-dev libz-dev

RUN mkdir -p /usr/local/src/git

RUN <<EOF
set -o errexit
set -o nounset
set -o pipefail

cd /usr/local/src/git
git clone https://github.com/MayamaTakeshi/sngrep
cd sngrep/
git checkout mrcp_support
./bootstrap.sh
./configure --enable-unicode --with-pcre
make

ln -s `pwd`/src/sngrep /usr/local/bin/sngrep2

EOF

RUN <<EOF
set -o errexit
set -o nounset
set -o pipefail

mkdir -p /root/tmp
cd /root/tmp
wget https://unimrcp.org/project/release-view/unimrcp-deps-1-6-0-tar-gz/download -O unimrcp-deps-1.6.0.tar.gz
tar xf unimrcp-deps-1.6.0.tar.gz
cd unimrcp-deps-1.6.0
sudo ./build-dep-libs.sh -s
EOF

RUN <<EOF
set -o errexit
set -o nounset
set -o pipefail

cd /usr/local/src/git/
git clone https://github.com/MayamaTakeshi/unimrcp.git
cd unimrcp
git checkout 9913f23691b3a1b8a7e84be5ba25478031352158
./bootstrap
./configure
make
rm -fr /usr/local/unimrcp # need to remove existing files
make install
sed -i -r 's|<ip type="auto"/>|<ip type="lo"/>|' /usr/local/unimrcp/conf/unimrcpserver.xml
sed -i -r 's|<ip type="auto"/>|<ip type="lo"/>|' /usr/local/unimrcp/conf/unimrcpclient.xml
EOF

RUN <<EOF
set -o errexit
set -o nounset
set -o pipefail

cd /usr/local/src/git
git clone https://github.com/MayamaTakeshi/swig-wrapper.git
cd swig-wrapper
git checkout 6e5becaea38418f8ad9909389bba3598b971f39c
rm -f CMakeCache.txt
cmake \
  -D APR_LIBRARY=/usr/local/apr/lib/libapr-1.so \
  -D APR_INCLUDE_DIR=/usr/local/apr/include/apr-1 \
  -D APU_LIBRARY=/usr/local/apr/lib/libaprutil-1.so \
  -D APU_INCLUDE_DIR=/usr/local/apr/include/apr-1 \
  -D WRAP_CPP=ON \
  -D WRAP_CSHARP=ON \
  -D WRAP_JAVA=ON \
  -D WRAP_PYTHON=ON \
  -D BUILD_C_EXAMPLE=ON \
  .
make
cp ./Python/wrapper/UniMRCP.py /usr/lib/python2.7/dist-packages
cp ./Python/_UniMRCP.so /usr/lib/python2.7/dist-packages

sudo /sbin/ldconfig
EOF

# Create the user
RUN groupadd --gid $USER_GID $user_name \
    && useradd --uid $USER_UID --gid $USER_GID -m $user_name

RUN echo $user_name ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$user_name \
    && chmod 0440 /etc/sudoers.d/$user_name

USER $user_name

RUN echo "set-option -g default-shell /bin/bash" >> ~/.tmux.conf

ENV TERM=xterm

RUN git config --global user.email $git_user_email
RUN git config --global user.name $git_user_name

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash && echo "nvm installation OK"

RUN . ~/.nvm/nvm.sh && nvm install v21.7.0

RUN . ~/.nvm/nvm.sh && npm install -g yarn

RUN mkdir -p ~/.vim/autoload ~/.vim/bundle && curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

RUN <<EOF cat > ~/.vimrc
set tabstop=4       " The width of a TAB is set to 4.
                    " Still it is a \t. It is just that
                    " Vim will interpret it to be having
                    " a width of 4.

set shiftwidth=4    " Indents will have a width of 4

set softtabstop=4   " Sets the number of columns for a TAB

set expandtab       " Expand TABs to spaces

execute pathogen#infect()
syntax on
filetype plugin indent on

set background=dark
colorscheme zenburn
EOF


RUN <<EOF
set -o errexit
set -o nounset
set -o pipefail

# install vim zenburn color theme
mkdir -p ~/.vim/colors/
cd ~/.vim/colors/
wget https://raw.githubusercontent.com/jnurmine/Zenburn/de2fa06a93fe1494638ec7b2fdd565898be25de6/colors/zenburn.vim
EOF

RUN <<EOF cat >> ~/.bashrc
export LANG=C.UTF-8
export PS1='\u@\h:\W\$ '
export TZ=Asia/Tokyo
export TERM=xterm-256color
. ~/.nvm/nvm.sh
EOF

RUN <<EOF
set -o errexit
set -o nounset
set -o pipefail

git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.1

echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc

# Source the asdf script directly within the same RUN block to get access to asdf ('source ~/.bashrc' will not work)
source "$HOME/.asdf/asdf.sh"
source "$HOME/.asdf/completions/asdf.bash"
EOF

RUN <<EOF
set -o errexit
set -o nounset
set -o pipefail

echo 'Installing rustup'
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -yq
EOF

